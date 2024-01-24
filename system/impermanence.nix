{ flakes, lib, ... }: {
  imports = [ flakes.impermanence.nixosModules.impermanence ];

  boot.initrd.postDeviceCommands = lib.mkAfter ''
    zfs rollback -r tank/local/root@blank
  '';

  fileSystems."/persist".neededForBoot = true;
  users.users.bhesson.hashedPasswordFile = "/persist/etc/users/bhesson";

  environment.persistence."/persist" = {
    directories = [
      "/etc/NetworkManager/system-connections"
      "/etc/secureboot"
    ];
  };
}
