{ flakes, pkgs, ... }: {
  imports = [ flakes.nixos-hardware.nixosModules.microsoft-surface-common ];
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

  boot = {
    kernelParams = [ "reboot=pci" ];
    initrd.kernelModules = [
      "surface_aggregator"
      "surface_aggregator_registry"
      "surface_aggregator_hub"
      "surface_hid_core"
      "surface_hid"
      "intel_lpss"
      "intel_lpss_pci"
      "8250_dw"
    ];
  };
}
