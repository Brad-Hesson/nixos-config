{ flakes, sysargs, ... }: {
  imports = [ flakes.impermanence.nixosModules.impermanence ];

  fileSystems."/persist".neededForBoot = true;
  users.users.bhesson.hashedPasswordFile = "/persist/etc/users/bhesson";
  users.users.root.hashedPasswordFile = "/persist/etc/users/root";
}
