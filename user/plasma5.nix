{ flakes, ... }: {
  imports = [ flakes.plasma-manager.homeManagerModules.plasma-manager ];
  home.persistence."/persist/home/bhesson".files = [
    ".config/plasma-org.kde.plasma.desktop-appletsrc"
    ".config/plasmashellrc"
  ];
}
