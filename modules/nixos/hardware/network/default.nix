{ lib, config, ... }:
let
  cfg = config.mods.hardware.network;
in
{
  options =
    let
      portType = with lib.types; listOf (either port (attrsOf types.port));
    in
    {
      mods.hardware.network = {
        ports = lib.mkOption {
          default = [ ];
          example = [ 8080 { from = 8999; to = 9003; } ];
          description = "ports and port ranges to forward";
          type = portType;
        };
        TCPPorts = lib.mkOption {
          default = [ ];
          example = [ 8080 { from = 8999; to = 9003; } ];
          description = "TCP ports and port ranges to forward";
          type = portType;
        };
        UDPPorts = lib.mkOption {
          default = [ ];
          example = [ 8080 { from = 8999; to = 9003; } ];
          description = "UDP ports and port ranges to forward";
          type = portType;
        };
      };
    };
  config = {
    # Easiest to use and most distros use this by default
    networking.networkmanager.enable = true;

    # Open ports in the firewall.
    networking.firewall =
      let
        ranges = l: builtins.filter builtins.isAttrs l;
        ports = l: builtins.filter builtins.isInt l;
      in
      {
        allowedTCPPorts = ports (cfg.ports ++ cfg.TCPPorts);
        allowedUDPPorts = ports (cfg.ports ++ cfg.UDPPorts);
        allowedTCPPortRanges = ranges (cfg.ports ++ cfg.TCPPorts);
        allowedUDPPortRanges = ranges (cfg.ports ++ cfg.UDPPorts);
      };

    # Allows incoming ssh connections
    services.openssh.enable = true;

    # Persist network connection settings
    persistif.directories = [
      "/etc/NetworkManager/system-connections"
    ];
  };
}
