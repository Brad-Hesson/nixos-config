{ lib, config, pkgs, ... }:
let cfg = config.mods.apps.steam; in {
  options = {
    mods.apps.steam.enable = lib.mkEnableOption "Steam";
  };
  config = lib.mkIf (cfg.enable) {
    programs.steam.enable = true;

    # Tell steam where to find ProtonGE
    environment.sessionVariables = {
      STEAM_EXTRA_COMPAT_TOOLS_PATHS =
        "\${HOME}/.steam/root/compatibilitytools.d";
    };
    environment.systemPackages = with pkgs; [
      # wine is sometimes needed to install Trackmania
      wineWowPackages.stable
      # Command to install latest ProtonGE
      protonup
    ];
  };
}
