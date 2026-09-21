{ inputs, pkgs, ... }: {
  imports = [
    inputs.nixos-hardware.nixosModules.microsoft-surface-common
    ./surface-dtx
    ./iptsd-pen-filter
  ];

  hardware.microsoft-surface.kernelVersion = "stable";
  services = {
    iptsd = {
      enable = true;
      config = {
        Touchscreen.DisableOnPalm = true;
        Touchscreen.DisableOnStylus = true;
      };
    };
    iptsdPenFilter = {
      enable = true;
      debounceMs = 50;
    };
  };
  environment.systemPackages = [
    pkgs.surface-control
  ];

  # thermal handling
  services.thermald.enable = true;
  services.power-profiles-daemon.enable = true;
}
