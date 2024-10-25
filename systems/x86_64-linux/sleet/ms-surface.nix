{ inputs, pkgs, ... }: {
  imports = [ inputs.nixos-hardware.nixosModules.microsoft-surface-common ];
  microsoft-surface.surface-control.enable = true;
  microsoft-surface.ipts.enable = true;

  services.thermald.enable = true;

  environment.systemPackages = [ pkgs.auto-cpufreq ];
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
