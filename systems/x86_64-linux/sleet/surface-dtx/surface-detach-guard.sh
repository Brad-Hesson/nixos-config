# PCI address of the Surface Book dGPU.
gpu_pci="0000:02:00.0"

notification_id=0
finished=0
selected_action=""

# Plasma session information. The detach handler itself runs as root.
session_uid=""
session_gid=""
session_user=""
session_home=""
runtime_dir=""

# Notification signal monitor state.
monitor_dir=""
monitor_fifo=""
monitor_pid=""
monitor_fd=""

# Keep the EC detach request alive while the interactive guard is running.
heartbeat_pid=""

log_info() {
  logger --tag surface-dtx-guard --priority daemon.info -- "$*"
}

log_warn() {
  logger --tag surface-dtx-guard --priority daemon.warning -- "$*"
}

# -----------------------------------------------------------------------------
# DTX heartbeat
# -----------------------------------------------------------------------------

# The Surface EC owns the detach-button LED and the detach timeout. While our
# interactive guard is waiting for applications to close, periodically reset
# that timeout. This keeps the native detachment operation alive (and therefore
# lets the EC keep presenting its normal in-progress LED indication).
start_heartbeat() {
  (
    while true; do
      if ! surface --quiet dtx heartbeat >/dev/null 2>&1; then
        logger --tag surface-dtx-guard --priority daemon.warning -- \
          "failed to send DTX heartbeat; stopping heartbeat loop"
        exit 0
      fi
      sleep 2
    done
  ) &
  heartbeat_pid=$!
  log_info "DTX heartbeat loop started"
}

# -----------------------------------------------------------------------------
# NVIDIA client detection
# -----------------------------------------------------------------------------

find_render_node() {
  local node device

  for node in /sys/class/drm/renderD*; do
    [[ -e "$node" ]] || continue
    device="$(readlink -f "$node/device" 2>/dev/null || true)"

    if [[ "$(basename "$device")" == "$gpu_pci" ]]; then
      echo "/dev/dri/$(basename "$node")"
      return 0
    fi
  done

  return 1
}

declare -A clients=()

get_clients() {
  clients=()

  local render_node dev pid proc comm
  local -a devices=()
  local -A seen=()

  render_node="$(find_render_node 2>/dev/null || true)"
  shopt -s nullglob

  # fuser examines users of the device nodes without issuing NVIDIA ioctls or
  # talking to NVML, so this does not intentionally wake a suspended dGPU.
  for dev in /dev/nvidia* /dev/nvidia-caps/*; do
    [[ -c "$dev" ]] || continue
    devices+=("$dev")
  done

  if [[ -n "$render_node" && -e "$render_node" ]]; then
    devices+=("$render_node")
  fi

  (( ${#devices[@]} > 0 )) || return 0

  while read -r pid; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    [[ -z "${seen[$pid]+x}" ]] || continue
    seen["$pid"]=1

    proc="/proc/$pid"
    [[ -r "$proc/comm" ]] || continue

    comm="$(cat "$proc/comm" 2>/dev/null || echo unknown)"
    clients["$pid"]="$comm"
  done < <(
    fuser "${devices[@]}" 2>/dev/null | tr ' ' '\n'
  )
}

clients_body() {
  local pid
  local -a pids=()
  local body=""

  mapfile -t pids < <(
    printf '%s\n' "${!clients[@]}" | sort -n
  )

  for pid in "${pids[@]}"; do
    body+="• ${clients[$pid]} — PID $pid"$'\n'
  done

  printf '%s' "$body"
}

clients_log_string() {
  local pid
  local -a pids=()
  local -a items=()

  mapfile -t pids < <(
    printf '%s\n' "${!clients[@]}" | sort -n
  )

  for pid in "${pids[@]}"; do
    items+=("${clients[$pid]}($pid)")
  done

  local IFS=', '
  printf '%s' "${items[*]}"
}

# -----------------------------------------------------------------------------
# Plasma session discovery
# -----------------------------------------------------------------------------

setup_plasma_session() {
  local kwin_pid=""
  local proc comm exe entry

  for proc in /proc/[0-9]*; do
    [[ -r "$proc/comm" ]] || continue

    comm="$(cat "$proc/comm" 2>/dev/null || true)"
    exe="$(readlink -f "$proc/exe" 2>/dev/null || true)"

    # NixOS wraps KWin, so /proc/$pid/comm may be a truncated wrapper name.
    if [[ "$comm" == *kwin_wayland* || "$exe" == *kwin_wayland* ]]; then
      kwin_pid="${proc##*/}"
      break
    fi
  done

  if [[ -z "$kwin_pid" ]]; then
    log_warn "cannot find Plasma Wayland session"
    return 1
  fi

  session_uid="$(stat -c '%u' "/proc/$kwin_pid")"
  session_gid="$(stat -c '%g' "/proc/$kwin_pid")"
  session_user="$(stat -c '%U' "/proc/$kwin_pid")"
  runtime_dir="/run/user/$session_uid"

  if [[ ! -S "$runtime_dir/bus" ]]; then
    log_warn "cannot find Plasma session bus at $runtime_dir/bus"
    return 1
  fi

  session_home=""
  if [[ -r "/proc/$kwin_pid/environ" ]]; then
    while IFS= read -r -d "" entry; do
      case "$entry" in
        HOME=*)
          session_home="${entry#*=}"
          ;;
      esac
    done < "/proc/$kwin_pid/environ"
  fi

  if [[ -z "$session_home" ]]; then
    session_home="/home/$session_user"
  fi

  log_info "Plasma session found: user=$session_user uid=$session_uid"
}

# Execute a command directly inside the Plasma user's session without creating
# a PAM session for every notification operation.
session_exec() {
  setpriv \
    --reuid="$session_uid" \
    --regid="$session_gid" \
    --init-groups \
    env \
      "HOME=$session_home" \
      "USER=$session_user" \
      "LOGNAME=$session_user" \
      "XDG_RUNTIME_DIR=$runtime_dir" \
      "DBUS_SESSION_BUS_ADDRESS=unix:path=$runtime_dir/bus" \
      "$@"
}

# -----------------------------------------------------------------------------
# Freedesktop notification D-Bus interface
# -----------------------------------------------------------------------------

# Send or replace the current notification directly over D-Bus.
# Arguments: summary body icon actions-array hints-dict timeout-ms
send_notification() {
  local summary="$1"
  local body="$2"
  local icon="$3"
  local actions="$4"
  local hints="$5"
  local timeout_ms="$6"
  local result id

  result="$(
    session_exec gdbus call \
      --session \
      --dest org.freedesktop.Notifications \
      --object-path /org/freedesktop/Notifications \
      --method org.freedesktop.Notifications.Notify \
      "Surface Detach" \
      "$notification_id" \
      "$icon" \
      "$summary" \
      "$body" \
      "$actions" \
      "$hints" \
      "$timeout_ms"
  )" || {
    log_warn "failed to send Plasma notification"
    return 1
  }

  if [[ "$result" =~ uint32[[:space:]]+([0-9]+) ]]; then
    id="${BASH_REMATCH[1]}"
  elif [[ "$result" =~ \(([0-9]+),\) ]]; then
    id="${BASH_REMATCH[1]}"
  else
    log_warn "could not parse notification ID from gdbus result: $result"
    return 1
  fi

  notification_id="$id"
}

close_notification() {
  (( notification_id > 0 )) || return 0

  session_exec gdbus call \
    --session \
    --dest org.freedesktop.Notifications \
    --object-path /org/freedesktop/Notifications \
    --method org.freedesktop.Notifications.CloseNotification \
    "$notification_id" \
    >/dev/null 2>&1 || true

  notification_id=0
}

show_checking() {
  send_notification \
    "Surface Detach" \
    "$1" \
    "view-refresh" \
    "[]" \
    "{'desktop-entry': <'surface-detach-guard'>, 'resident': <true>, 'transient': <false>, 'urgency': <byte 1>}" \
    0
}

show_busy() {
  local body="$1"

  send_notification \
    "NVIDIA GPU in use" \
    "$body" \
    "dialog-warning" \
    "['cancel', '❌ Cancel', 'unsafe', '⚠️ Open Anyway']" \
    "{'desktop-entry': <'surface-detach-guard'>, 'resident': <true>, 'transient': <false>, 'urgency': <byte 1>}" \
    0
}

show_status() {
  local summary="$1"
  local body="$2"
  local icon="$3"
  local timeout_ms="$4"
  local urgency_byte="$5"

  send_notification \
    "$summary" \
    "$body" \
    "$icon" \
    "[]" \
    "{'desktop-entry': <'surface-detach-guard'>, 'resident': <true>, 'transient': <false>, 'urgency': <byte $urgency_byte>}" \
    "$timeout_ms"
}

start_notification_monitor() {
  monitor_dir="$(mktemp -d)"
  monitor_fifo="$monitor_dir/events"
  mkfifo "$monitor_fifo"

  # Open the FIFO read/write in this shell so neither endpoint blocks waiting
  # for the other to open it.
  exec {monitor_fd}<>"$monitor_fifo"

  session_exec stdbuf -oL -eL gdbus monitor \
    --session \
    --dest org.freedesktop.Notifications \
    --object-path /org/freedesktop/Notifications \
    >"$monitor_fifo" 2>/dev/null &
  monitor_pid=$!

  log_info "notification action monitor started"
}

restart_notification_monitor() {
  if [[ -n "$monitor_pid" ]]; then
    kill "$monitor_pid" 2>/dev/null || true
    wait "$monitor_pid" 2>/dev/null || true
  fi

  session_exec stdbuf -oL -eL gdbus monitor \
    --session \
    --dest org.freedesktop.Notifications \
    --object-path /org/freedesktop/Notifications \
    >"$monitor_fifo" 2>/dev/null &
  monitor_pid=$!

  log_warn "notification action monitor restarted"
}

# While the GPU is busy, keep checking automatically. The notification is
# deliberately non-transient and has a real desktop-entry identity, so Plasma
# can minimize it into the notification center without destroying it.
#
# We only replace the notification when the client set actually changes. That
# keeps the UI quiet while still removing processes from the list as they close.
# When the final client disappears, return immediately and continue with the
# normal safe-detach path.
wait_for_busy_resolution() {
  local line=""
  local last_clients=""
  local current_clients=""
  local process_list=""
  local busy_body=""
  local next_check=0

  last_clients="$(clients_log_string)"
  process_list="$(clients_body)"
  busy_body="${process_list}"$'\n'$'Close these apps before detaching. This list updates automatically.'

  show_busy "$busy_body"
  log_info "waiting for GPU clients to close; automatic polling active"
  next_check=$((SECONDS + 1))

  while true; do
    # Keep processing notification actions while waiting. A short timeout lets
    # us poll the GPU-client set without a separate background process.
    if IFS= read -r -t 1 -u "$monitor_fd" line; then
      if [[ "$line" == *"ActionInvoked"* && "$line" == *"uint32 $notification_id"* ]]; then
        if [[ "$line" == *"'cancel'"* ]]; then
          selected_action="cancel"
          return 0
        fi
        if [[ "$line" == *"'unsafe'"* ]]; then
          selected_action="unsafe"
          return 0
        fi
      fi

      # A real close is different from Plasma's down-arrow/minimize operation.
      # If the notification is actually removed, cancel so the root handler
      # cannot remain blocked with no UI available to recover it.
      if [[ "$line" == *"NotificationClosed"* && "$line" == *"uint32 $notification_id"* ]]; then
        log_info "busy notification was explicitly closed; cancelling detach"
        selected_action="cancel"
        return 0
      fi
    else
      if [[ -n "$monitor_pid" ]] && ! kill -0 "$monitor_pid" 2>/dev/null; then
        restart_notification_monitor
      fi
    fi

    if (( SECONDS < next_check )); then
      continue
    fi
    next_check=$((SECONDS + 1))

    get_clients

    if (( ${#clients[@]} == 0 )); then
      log_info "all NVIDIA GPU clients closed; continuing detach automatically"
      selected_action="clear"
      return 0
    fi

    current_clients="$(clients_log_string)"

    if [[ "$current_clients" != "$last_clients" ]]; then
      log_info "GPU client list changed: ${#clients[@]} client(s): $current_clients"

      process_list="$(clients_body)"
      busy_body="${process_list}"$'\n'$'Close these apps before detaching. This list updates automatically.'
      show_busy "$busy_body"

      last_clients="$current_clients"
    fi
  done
}

# -----------------------------------------------------------------------------
# Base preparation
# -----------------------------------------------------------------------------

unmount_usb_storage() {
  local usb_dev dev

  shopt -s nullglob

  for usb_dev in /dev/disk/by-id/usb-*; do
    dev="$(readlink -f "$usb_dev" 2>/dev/null || true)"
    [[ -n "$dev" ]] || continue

    if findmnt -rn -S "$dev" >/dev/null 2>&1; then
      log_info "unmounting USB storage before detach: $dev"

      if ! umount "$dev"; then
        log_warn "failed to unmount $dev; aborting detach"
        return 1
      fi
    fi
  done
}

prepare_and_finish_safe() {
  log_info "GPU clear; preparing base"
  show_status \
    "Preparing Surface base" \
    "GPU is clear. Preparing the base…" \
    "computer-laptop" \
    0 \
    1

  if ! unmount_usb_storage; then
    show_status \
      "Detach blocked" \
      "A USB storage device could not be unmounted. The base will remain attached." \
      "dialog-error" \
      5000 \
      1
    finished=1
    return 1
  fi

  log_info "allowing Surface base latch to unlock"

  # Match the cancellation UX: replace the long-running persistent notification
  # with a short completion toast, then let Plasma expire it normally. The DTX
  # daemon unlocks the latch immediately after this handler returns success.
  show_status \
    "Ready to detach" \
    "Unlocking the Surface base…" \
    "emblem-ok-symbolic" \
    1500 \
    0

  finished=1
  return 0
}

prepare_and_finish_unsafe() {
  log_warn "user explicitly requested UNSAFE detach with NVIDIA clients still open"
  show_status \
    "Unsafe detach requested" \
    "Preparing the base while GPU applications are still open…" \
    "dialog-warning" \
    0 \
    2

  if ! unmount_usb_storage; then
    show_status \
      "Detach blocked" \
      "A USB storage device could not be unmounted. The base will remain attached." \
      "dialog-error" \
      5000 \
      1
    finished=1
    return 1
  fi

  log_warn "allowing Surface base latch to unlock UNSAFELY"
  show_status \
    "Unsafe detach allowed" \
    "Unlocking the Surface base with GPU applications still open…" \
    "dialog-warning" \
    1500 \
    1

  finished=1
  return 0
}

# Kill the D-Bus monitor and remove its FIFO on every exit. If the guard dies
# unexpectedly, leave a short notification explaining that the detach stopped.
trap '
  if [[ -n "${heartbeat_pid:-}" ]]; then
    kill "$heartbeat_pid" 2>/dev/null || true
    wait "$heartbeat_pid" 2>/dev/null || true
  fi
  if [[ -n "${monitor_pid:-}" ]]; then
    kill "$monitor_pid" 2>/dev/null || true
    wait "$monitor_pid" 2>/dev/null || true
  fi
  if [[ -n "${monitor_dir:-}" ]]; then
    rm -rf "$monitor_dir"
  fi
  if [[ "${finished:-0}" != 1 ]]; then
    logger --tag surface-dtx-guard --priority daemon.warning -- "detach guard exited before completing"
  fi
' EXIT

# -----------------------------------------------------------------------------
# Main state machine
# -----------------------------------------------------------------------------

log_info "detach request received"
start_heartbeat
setup_plasma_session
start_notification_monitor
show_checking "Checking NVIDIA GPU…"

while true; do
  log_info "checking NVIDIA GPU clients"
  get_clients

  if (( ${#clients[@]} == 0 )); then
    log_info "no NVIDIA GPU clients found"
    prepare_and_finish_safe
    exit $?
  fi

  log_info "GPU busy: ${#clients[@]} client(s): $(clients_log_string)"

  selected_action=""
  wait_for_busy_resolution

  case "$selected_action" in
    clear)
      prepare_and_finish_safe
      exit $?
      ;;

    cancel)
      log_info "user cancelled detach"
      show_status \
        "Detach cancelled" \
        "The Surface base will remain attached." \
        "dialog-cancel" \
        1500 \
        0
      finished=1
      exit 1
      ;;

    unsafe)
      prepare_and_finish_unsafe
      exit $?
      ;;

    *)
      log_warn "unexpected notification action: $selected_action"
      exit 1
      ;;
  esac
done
