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
      ".config/plasmashellrc"
      ".config/touchpadxlibinputrc"
      ".local/share/user-places.xbel"
    ];
  };

  programs.plasma = {
    enable = true;
    workspace = {
      theme = "breeze-dark";
      colorScheme = "BreezeDark";
      clickItemTo = "select";
    };
  };
}
