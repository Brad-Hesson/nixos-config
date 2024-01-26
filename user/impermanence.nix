{ flakes, ... }: {
  imports = [ flakes.nixosModules.home-manager.impermanence ];
  home.persistence."/persist/home/bhesson".directories = [
    "Desktop"
    "Code"
  ];
}
