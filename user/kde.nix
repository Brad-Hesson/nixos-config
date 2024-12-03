{ flakes, ... }: {
  imports = [ flakes.plasma-manager.homeManagerModules.plasma-manager ];

  home.persistence."/persist/home/bhesson" = {
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
      ".config/touchpadxlibinputrc"
      ".local/share/user-places.xbel"
    ];
  };

  programs.plasma = {
    overrideConfig = true;
    enable = true;
    workspace = {
      theme = "breeze-dark";
      colorScheme = "BreezeDark";
      clickItemTo = "select";
    };
    configFile = {
      "kcminputrc"."Libinput/1118/2479/Microsoft Surface 045E:09AF Touchpad"."ClickMethod" = 2;
      "kcminputrc"."Libinput/1118/2479/Microsoft Surface 045E:09AF Touchpad"."NaturalScroll" = true;
      "powerdevilrc" = {
        "AC/SuspendAndShutdown" = {
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
        "AC/Display" = {
          "DisplayBrightness" = 100;
          "UseProfileSpecificDisplayBrightness" = true;
        };
        "Battery/Display" = {
          "DisplayBrightness" = 50;
          "UseProfileSpecificDisplayBrightness" = true;
        };
      };
    };
  };
}
