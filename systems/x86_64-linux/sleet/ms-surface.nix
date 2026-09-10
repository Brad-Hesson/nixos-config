{ inputs, pkgs, ... }: {
  imports = [
    inputs.nixos-hardware.nixosModules.microsoft-surface-common
    # ./surface-dtx-daemon.nix
  ];

  hardware.microsoft-surface.kernelVersion = "stable";
  services.iptsd.enable = true;
  environment.systemPackages = [
    pkgs.surface-control
  ];

  # thermal handling
  services.thermald.enable = true;
  services.power-profiles-daemon.enable = true;
}
