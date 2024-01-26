{ flakes, lib, ... }: {
  imports = [ flakes.impermanence.nixosModules.impermanence ];

  boot.initrd.postDeviceCommands = lib.mkAfter ''
    zfs rollback -r tank/local/root@blank
  '';
  boot.kernelParams = [ "elevator=none" ];
  boot.kernelPatches = [{
    name = "enable RT_FULL";
    patch = null;
    extraConfig = ''
      PREEMPT y
      PREEMPT_BUILD y
      PREEMPT_VOLUNTARY n
      PREEMPT_COUNT y
      PREEMPTION y
    '';
  }];

  fileSystems."/persist".neededForBoot = true;
  users.users.bhesson.hashedPasswordFile = "/persist/etc/users/bhesson";
}
