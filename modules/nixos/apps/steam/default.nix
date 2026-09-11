{ lib, config, pkgs, ... }:
let cfg = config.mods.apps.steam; in {
  options = {
    mods.apps.steam.enable = lib.mkEnableOption "Steam";
  };
  config = lib.mkIf (cfg.enable) {
    programs.steam.enable = true;
    programs.gamemode.enable = true;

    mods.hardware.network.TCPPorts = [27036 27037];
    mods.hardware.network.UDPPorts = [27031 27032 27033 27034 27035 27036];

    # Tell steam where to find ProtonGE
    environment.sessionVariables = {
      STEAM_EXTRA_COMPAT_TOOLS_PATHS =
        "\${HOME}/.steam/root/compatibilitytools.d";
    };
    environment.systemPackages = with pkgs; [
      # wine is sometimes needed to install Trackmania
      wineWow64Packages.stable
      # Command to install latest ProtonGE
      protonup-ng
    ];
  };
}
