{ inputs, lib, osConfig, ... }:
let
  osCfg = osConfig.mods.display.plasma;
in
{
  imports = [ inputs.plasma-manager.homeManagerModules.plasma-manager ];
  config = lib.mkIf (osCfg.enable) {
    programs.plasma = {
      enable = true;
      overrideConfig = true;
      workspace = {
        theme = "breeze-dark";
        colorScheme = "BreezeDark";
        clickItemTo = "select";
      };
      # TODO: move to glacier system folder somehow (this is a home-manager thing)
      configFile = {
        "powerdevilrc" = {
          "AC/Display" = {
            "DimDisplayIdleTimeoutSec" = -1;
            "DimDisplayWhenIdle" = false;
            "TurnOffDisplayIdleTimeoutSec" = -1;
            "TurnOffDisplayWhenIdle" = false;
          };
          "AC/Performance" = {
            "PowerProfile" = "performance";
          };
          "AC/SuspendAndShutdown" = {
            "AutoSuspendAction" = 0;
            "PowerButtonAction" = 8;
          };
        };
      };
    };

    services.kdeconnect = {
      enable = true;
      indicator = true;
    };

    persistif = {
      directories = [
        ".local/share/kwalletd"
        ".local/share/kscreen"
        ".local/share/baloo"
        ".local/share/dolphin"
      ];
      files = [
        ".config/plasma-org.kde.plasma.desktop-appletsrc"
        ".config/plasmashellrc"
        ".local/share/user-places.xbel"
      ];
    };
  };
}
