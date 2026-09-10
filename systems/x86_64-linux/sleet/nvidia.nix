{ config, ... }: {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  services.switcherooControl.enable = true;

  hardware.nvidia = {
    modesetting.enable = true;

    powerManagement = {
      enable = true;
      finegrained = true;
    };

    open = false;

    nvidiaSettings = true;

    package = config.boot.kernelPackages.nvidiaPackages.beta;

    prime = {
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:2:0:0";

      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
    };
  };
}
