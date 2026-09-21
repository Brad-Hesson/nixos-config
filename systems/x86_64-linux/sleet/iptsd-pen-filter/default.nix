{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.iptsdPenFilter;

  python = pkgs.python3.withPackages (pythonPackages: with pythonPackages; [
    evdev
  ]);

  iptsdPenFilter = pkgs.writeShellApplication {
    name = "iptsd-pen-filter";

    text = ''
      exec ${python}/bin/python3 ${./iptsd-pen-filter.py} "$@"
    '';
  };
in
{
  options.services.iptsdPenFilter = {
    enable = lib.mkEnableOption "IPTSD stylus proximity dropout filter";

    debounceMs = lib.mkOption {
      type = lib.types.int;
      default = 50;

      description = ''
        Time in milliseconds to wait before emitting BTN_TOOL_PEN=0
        after a proximity dropout that occurred while BTN_TOUCH=1.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [
      "uinput"
    ];

    environment.systemPackages = [
      iptsdPenFilter
    ];

    systemd.services.iptsd-pen-filter = {
      description = "IPTSD stylus proximity dropout filter";

      wantedBy = [
        "multi-user.target"
      ];

      serviceConfig = {
        Type = "simple";

        ExecStart = ''
          ${iptsdPenFilter}/bin/iptsd-pen-filter \
            --debounce-ms ${toString cfg.debounceMs}
        '';

        Restart = "always";
        RestartSec = "1s";
      };
    };
  };
}