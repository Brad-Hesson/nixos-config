#!/usr/bin/env python3

import argparse
import select
import sys
import time

import evdev
from evdev import InputDevice, UInput, ecodes as e


def find_device(name: str) -> InputDevice:
    while True:
        for path in evdev.list_devices():
            try:
                dev = InputDevice(path)
            except OSError:
                continue

            if dev.name == name:
                return dev

            dev.close()

        print(
            f"Waiting for input device: {name}",
            file=sys.stderr,
            flush=True,
        )
        time.sleep(0.5)


def main() -> None:
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--device-name",
        default="IPTSD Virtual Stylus 045E:09B2",
    )

    parser.add_argument(
        "--output-name",
        default="Filtered IPTSD Virtual Stylus 045E:09B2",
    )

    parser.add_argument(
        "--debounce-ms",
        type=float,
        default=50.0,
        help="Delay before releasing BTN_TOOL_PEN after a suppressed dropout",
    )

    args = parser.parse_args()

    dev = find_device(args.device_name)
    info = dev.info

    # Snapshot current button/tool state in case the pen is already
    # hovering when the filter starts.
    active_keys = set(dev.active_keys())

    ui = UInput.from_device(
        dev,
        name=args.output_name,
        vendor=info.vendor,
        product=info.product,
        version=info.version,
        bustype=info.bustype,
        phys="iptsd-proximity-filter",
        input_props=dev.input_props(),
    )

    raw_tool_pen = e.BTN_TOOL_PEN in active_keys
    touch_down = e.BTN_TOUCH in active_keys

    # The state we have actually exposed to KWin/libinput.
    emitted_tool_pen = raw_tool_pen or touch_down

    # This means raw BTN_TOOL_PEN went low while the pen was physically
    # touching the display, so we intentionally suppressed it.
    suppressed_tool_off = touch_down and not raw_tool_pen

    off_deadline = None
    delay = args.debounce_ms / 1000.0

    try:
        # Prevent KWin/libinput from receiving the unfiltered device.
        dev.grab()

        print(
            f"Filtering {dev.path} ({dev.name}) "
            f"-> {ui.device.path} ({args.output_name})",
            file=sys.stderr,
            flush=True,
        )

        # uinput devices start with all EV_KEY states released.
        # Restore the current state.
        initial_keys = set(active_keys)

        # BTN_TOUCH implies the pen must logically be present.
        if touch_down:
            initial_keys.add(e.BTN_TOOL_PEN)

        for code in initial_keys:
            ui.write(e.EV_KEY, code, 1)

        if initial_keys:
            ui.syn()

        while True:
            timeout = None

            if off_deadline is not None:
                timeout = max(
                    0.0,
                    off_deadline - time.monotonic(),
                )

            readable, _, _ = select.select(
                [dev.fd],
                [],
                [],
                timeout,
            )

            #
            # Debounce timer expired.
            #
            if not readable:
                if (
                    off_deadline is not None
                    and time.monotonic() >= off_deadline
                ):
                    off_deadline = None

                    if (
                        not touch_down
                        and not raw_tool_pen
                        and emitted_tool_pen
                    ):
                        ui.write(
                            e.EV_KEY,
                            e.BTN_TOOL_PEN,
                            0,
                        )
                        ui.syn()

                        emitted_tool_pen = False

                continue

            for event in dev.read():

                #
                # BTN_TOOL_PEN
                #
                if (
                    event.type == e.EV_KEY
                    and event.code == e.BTN_TOOL_PEN
                ):
                    if event.value:
                        #
                        # Proximity-on is always passed immediately.
                        #
                        raw_tool_pen = True
                        suppressed_tool_off = False
                        off_deadline = None

                        if not emitted_tool_pen:
                            ui.write(
                                e.EV_KEY,
                                e.BTN_TOOL_PEN,
                                1,
                            )
                            emitted_tool_pen = True

                    else:
                        raw_tool_pen = False

                        if touch_down:
                            #
                            # Impossible state:
                            #
                            # BTN_TOUCH = 1
                            # BTN_TOOL_PEN = 0
                            #
                            # Suppress the proximity loss.
                            #
                            suppressed_tool_off = True
                            off_deadline = None

                        elif off_deadline is not None:
                            #
                            # We previously suppressed an off event
                            # while touching and are already waiting
                            # to see whether it was real.
                            #
                            pass

                        else:
                            #
                            # Normal hover exit.
                            #
                            # No debounce or latency is added here.
                            #
                            if emitted_tool_pen:
                                ui.write(
                                    e.EV_KEY,
                                    e.BTN_TOOL_PEN,
                                    0,
                                )
                                emitted_tool_pen = False

                #
                # BTN_TOUCH
                #
                elif (
                    event.type == e.EV_KEY
                    and event.code == e.BTN_TOUCH
                ):
                    if event.value:
                        touch_down = True
                        off_deadline = None

                        if not raw_tool_pen:
                            suppressed_tool_off = True

                        #
                        # Never expose contact without tool presence.
                        #
                        if not emitted_tool_pen:
                            ui.write(
                                e.EV_KEY,
                                e.BTN_TOOL_PEN,
                                1,
                            )
                            emitted_tool_pen = True

                        ui.write_event(event)

                    else:
                        touch_down = False
                        ui.write_event(event)

                        #
                        # If TOOL_PEN went low during the stroke and
                        # never recovered, don't simply forget that.
                        #
                        # Wait briefly after touch-up. If TOOL_PEN
                        # remains low, expose the proximity loss.
                        #
                        if (
                            suppressed_tool_off
                            and not raw_tool_pen
                        ):
                            off_deadline = (
                                time.monotonic() + delay
                            )

                        suppressed_tool_off = False

                else:
                    #
                    # Everything else is untouched:
                    #
                    # X/Y
                    # pressure
                    # tilt
                    # BTN_STYLUS
                    # eraser
                    # SYN_REPORT
                    # etc.
                    #
                    ui.write_event(event)

    finally:
        try:
            dev.ungrab()
        except OSError:
            pass

        ui.close()
        dev.close()


if __name__ == "__main__":
    main()