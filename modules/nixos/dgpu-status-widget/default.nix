{ config, lib, pkgs, ... }:

let
  cfg = config.mods.plasmaDgpuStatus;

  # Uses only sysfs reads. In particular, this does not call nvidia-smi,
  # NVML, lspci, nvidia-settings, etc.
  statusScript = pkgs.writeShellScript "plasma-dgpu-status" ''
    gpu="/sys/bus/pci/devices/${cfg.pciAddress}"

    if [[ ! -d "$gpu" ]]; then
      printf 'detached|unavailable\n'
      exit 0
    fi

    power="unknown"
    runtime="unknown"

    if [[ -r "$gpu/power_state" ]]; then
      IFS= read -r power < "$gpu/power_state" || true
    fi

    if [[ -r "$gpu/power/runtime_status" ]]; then
      IFS= read -r runtime < "$gpu/power/runtime_status" || true
    fi

    printf '%s|%s\n' "$power" "$runtime"
  '';

  metadata = pkgs.writeText "metadata.json" (builtins.toJSON {
    KPlugin = {
      Id = "local.dgpu-power-state";
      Name = "dGPU Power State";
      Description = "Shows the PCI power state of a discrete GPU";
      Icon = "video-display";
      Category = "System Information";
      Version = "1.0";
      License = "MIT";
    };

    "X-Plasma-API-Minimum-Version" = "6.0";
    KPackageStructure = "Plasma/Applet";
  });

  mainQml = pkgs.writeText "main.qml" ''
    import QtQuick
    import QtQuick.Layouts

    import org.kde.kirigami as Kirigami
    import org.kde.plasma.core as PlasmaCore
    import org.kde.plasma.plasma5support as Plasma5Support
    import org.kde.plasma.plasmoid

    PlasmoidItem {
        id: root

        property string powerState: "unknown"
        property string runtimeStatus: "unknown"

        readonly property bool hollowIndicator:
            powerState === "D3cold"

        readonly property color statusColor: {
            switch (powerState) {
            case "D0":
                return Kirigami.Theme.positiveTextColor
            case "D1":
            case "D2":
            case "D3hot":
                return Kirigami.Theme.neutralTextColor
            case "D3cold":
                return Kirigami.Theme.disabledTextColor
            case "detached":
                return Kirigami.Theme.negativeTextColor
            default:
                return Kirigami.Theme.textColor
            }
        }

        readonly property string stateDescription: {
            switch (powerState) {
            case "D0":
                return "GPU is powered (D0)"
            case "D1":
                return "GPU is in D1"
            case "D2":
                return "GPU is in D2"
            case "D3hot":
                return "GPU is suspended in D3hot"
            case "D3cold":
                return "GPU is powered down in D3cold"
            case "detached":
                return "dGPU is not present"
            default:
                return "GPU power state is unknown"
            }
        }

        preferredRepresentation: fullRepresentation
        Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

        function updateStatus(output) {
            const fields = output.trim().split("|")

            powerState =
                fields.length > 0 && fields[0] !== ""
                ? fields[0]
                : "unknown"

            runtimeStatus =
                fields.length > 1 && fields[1] !== ""
                ? fields[1]
                : "unknown"
        }

        function refresh() {
            executable.connectSource("${statusScript}")
        }

        Plasma5Support.DataSource {
            id: executable

            engine: "executable"
            connectedSources: []

            onNewData: function(sourceName, data) {
                if (data["exit code"] === 0) {
                    root.updateStatus(data["stdout"] || "")
                } else {
                    root.powerState = "unknown"
                    root.runtimeStatus = "unknown"
                }

                disconnectSource(sourceName)
            }
        }

        Timer {
            interval: ${toString cfg.pollIntervalMs}
            running: true
            repeat: true
            triggeredOnStart: true

            onTriggered: root.refresh()
        }

        fullRepresentation: Item {
            id: panelItem

            implicitWidth: Kirigami.Units.gridUnit * 2
            implicitHeight: Kirigami.Units.gridUnit * 2

            Layout.minimumWidth: implicitWidth
            Layout.preferredWidth: implicitWidth
            Layout.maximumWidth: implicitWidth
            Layout.fillHeight: true

            Kirigami.Icon {
                id: gpuIcon

                anchors.centerIn: parent

                width: Math.min(parent.width, parent.height) * 0.68
                height: width

                source: "video-display"

                opacity: {
                    switch (root.powerState) {
                    case "D0":
                        return 1.0
                    case "D3hot":
                        return 0.75
                    case "D3cold":
                        return 0.45
                    case "detached":
                        return 0.25
                    default:
                        return 0.6
                    }
                }
            }

            Rectangle {
                id: stateIndicator

                width: Math.max(
                    7,
                    Math.min(panelItem.width, panelItem.height) * 0.23
                )
                height: width
                radius: width / 2

                anchors.right: gpuIcon.right
                anchors.bottom: gpuIcon.bottom

                anchors.rightMargin: -width * 0.15
                anchors.bottomMargin: -height * 0.15

                color:
                    root.hollowIndicator
                    ? "transparent"
                    : root.statusColor

                border.color: root.statusColor

                border.width:
                    root.hollowIndicator
                    ? Math.max(1, width * 0.18)
                    : 1
            }

            PlasmaCore.ToolTipArea {
                anchors.fill: parent

                mainText: "dGPU: " + root.powerState

                subText:
                    root.powerState === "detached"
                    ? "PCI device ${cfg.pciAddress} is not present"
                    : root.stateDescription
                      + "\nRuntime PM: " + root.runtimeStatus
                      + "\nPCI: ${cfg.pciAddress}"
            }
        }
    }
  '';

  widget = pkgs.runCommand "plasma-dgpu-power-state-widget" { } ''
    dst="$out/share/plasma/plasmoids/local.dgpu-power-state"

    mkdir -p "$dst/contents/ui"

    cp ${metadata} "$dst/metadata.json"
    cp ${mainQml} "$dst/contents/ui/main.qml"
  '';

in
{
  options.mods.plasmaDgpuStatus = {
    enable = lib.mkEnableOption "Plasma dGPU power-state widget";

    pciAddress = lib.mkOption {
      type = lib.types.str;
      default = "0000:01:00.0";
      description = ''
        PCI address of the dGPU under /sys/bus/pci/devices.
      '';
    };

    pollIntervalMs = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1000;
      description = ''
        How often the widget polls the kernel's cached PCI power state,
        in milliseconds.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      widget
    ];
  };
}