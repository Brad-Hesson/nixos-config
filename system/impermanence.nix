{ flakes, lib, ... }: {
  imports = [ flakes.impermanence.nixosModules.impermanence ];

  boot.initrd.postDeviceCommands = lib.mkAfter ''
    zfs rollback -r tank/local/root@blank
  '';

  fileSystems."/persist".neededForBoot = true;
}
