{ inputs, ... }: {
  imports = [ inputs.plasma-manager.homeManagerModules.plasma-manager ];

  programs.plasma = {
    enable = true;
    overrideConfig = true;
    workspace = {
      theme = "breeze-dark";
      colorScheme = "BreezeDark";
      clickItemTo = "select";
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
}
