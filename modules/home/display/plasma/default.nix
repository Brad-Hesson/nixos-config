{ inputs, lib, osConfig, ... }:
let
  osCfg = osConfig.mods.display.plasma;
in
{
  imports = [ inputs.plasma-manager.homeModules.plasma-manager ];
  config = lib.mkIf (osCfg.enable) {
    programs.plasma = {
      enable = true;
      overrideConfig = false;
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
        "baloofilerc"."Basic Settings"."Indexing-Enabled" = {
          value = false;
          immutable = true;
        };
      };
    };

    persistif = {
      directories = [
        ".local/share/kwalletd"
        ".local/share/kscreen"
        ".local/share/baloo"
        ".local/share/dolphin"
        # akonadi (pulled in by programs.kde-pim): db + agent registry must persist together
        ".local/share/akonadi"
        ".local/share/akonadi_migration_agent"
        ".config/akonadi"
        # data dirs for the default akonadi resources
        ".local/share/contacts"
        ".local/share/local-mail"
        ".local/share/apps/korganizer"
      ];
      files = [
        {
          file = ".config/plasma-org.kde.plasma.desktop-appletsrc";
          method = "symlink";
        }
        {
          file = ".config/kwinoutputconfig.json";
          method = "symlink";
        }
        {
          file = ".config/plasmashellrc";
          method = "symlink";
        }
        {
          file = ".config/kactivitymanagerdrc";
          method = "symlink";
        }
        {
          file = ".local/state/kactivitymanagerdstaterc";
          method = "symlink";
        }
        ".local/share/user-places.xbel"
        {
          file = ".config/akonadi-firstrunrc";
          method = "symlink";
        }
        {
          file = ".config/akonadi_contacts_resource_0rc";
          method = "symlink";
        }
        {
          file = ".config/akonadi_ical_resource_0rc";
          method = "symlink";
        }
        {
          file = ".config/akonadi_maildir_resource_0rc";
          method = "symlink";
        }
        {
          file = ".config/akonadi_indexing_agentrc";
          method = "symlink";
        }
      ];
    };
  };
}
