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
        "kwinrc"."EdgeBarrier" = {
          "EdgeBarrier" = 0;
        };
        "kcminputrc"."Libinput/1118/2479/Microsoft Surface 045E:09AF Touchpad" = {
          "ClickMethod" = 2;
          "NaturalScroll" = true;
        };
        "powerdevilrc" = {
          "AC/RunScript" = {
            "IdleTimeoutCommand" = "/home/bhesson/Desktop/screensaver.sh";
            "RunScriptIdleTimeoutSec" = 1800;
          };
          "AC/Display" = {
            "DisplayBrightness" = 100;
            "UseProfileSpecificDisplayBrightness" = true;
            "DimDisplayIdleTimeoutSec" = -1;
            "DimDisplayWhenIdle" = false;
            "TurnOffDisplayIdleTimeoutSec" = -1;
            "TurnOffDisplayWhenIdle" = false;
          };
          "Battery/Display" = {
            "DisplayBrightness" = 50;
            "UseProfileSpecificDisplayBrightness" = true;
          };
          "AC/Performance" = {
            "PowerProfile" = "performance";
          };
          "AC/SuspendAndShutdown" = {
            "PowerButtonAction" = 8;
            "AutoSuspendAction" = 0;
            "LidAction" = 64;
          };
          "Battery/SuspendAndShutdown" = {
            "AutoSuspendAction" = 0;
            "LidAction" = 64;
          };
          "LowBattery/SuspendAndShutdown" = {
            "AutoSuspendAction" = 0;
            "LidAction" = 64;
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
        ".config/kwinoutputconfig.json"
        ".config/plasmashellrc"
        ".local/share/user-places.xbel"
      ];
    };
  };
}
