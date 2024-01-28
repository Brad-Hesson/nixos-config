{ flakes, ... }: {
  imports = [ flakes.impermanence.nixosModules.home-manager.impermanence ];
  home.persistence."/persist/home/bhesson".allowOther = true;
}
