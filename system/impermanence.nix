{ flakes, sysargs, ... }: {
  imports = [ flakes.impermanence.nixosModules.impermanence ];

  fileSystems."/persist".neededForBoot = true;
  users.users.bhesson.passwordFile = "/persist/etc/users/bhesson";
  users.users.root.passwordFile = "/persist/etc/users/root";
}
