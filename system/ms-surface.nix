{ flakes, pkgs, ... }: {
  imports = [ flakes.nixos-hardware.nixosModules.microsoft-surface-common ];
  services.iptsd.enable = true;

  services.thermald.enable = true;

  environment.systemPackages = [ pkgs.auto-cpufreq pkgs.surface-control ];
  services.power-profiles-daemon.enable = false;
  services.auto-cpufreq.enable = true;
  services.auto-cpufreq.settings = {
    battery = {
      governor = "powersave";
      turbo = "never";
    };
    charger = {
      governor = "performance";
      turbo = "auto";
    };
  };
}
