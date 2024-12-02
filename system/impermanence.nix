{ flakes, lib, ... }: {
  imports = [ flakes.impermanence.nixosModules.impermanence ];

  boot.initrd.postResumeCommands = lib.mkAfter ''
    zfs rollback -r tank/local/root@blank
  '';

  fileSystems."/persist".neededForBoot = true;

  environment.persistence."/persist".directories = [
    "/root/.ssh"
  ];
}
