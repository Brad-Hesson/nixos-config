{ lib, config, ... }:
let
  cfg = config.mods.hardware.network;
in
{
  options = {
    mods.hardware.network.ports = { };
  };
  config = {
    # Easiest to use and most distros use this by default
    networking.networkmanager.enable = true;

    # Open ports in the firewall.
    networking.firewall =
      let
        both = [{ from = 1714; to = 1764; }]; # KDE Connect
      in
      {
        allowedTCPPortRanges = both ++ [ ];
        allowedUDPPortRanges = both ++ [ ];
      };

    # Allows incoming ssh connections
    services.openssh.enable = true;

    # Persist network connection settings
    persistif.directories = [
      "/etc/NetworkManager/system-connections"
    ];
  };
}
