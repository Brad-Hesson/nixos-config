{ flakes, ... }: {
  imports = [ flakes.nixos-hardware.nixosModules.microsoft-surface-common ];
  microsoft-surface.surface-control.enable = true;
}
