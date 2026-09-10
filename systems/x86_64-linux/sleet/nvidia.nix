{ config, ... }: {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "modesetting" "nvidia" ];

  services.switcherooControl.enable = true;

  services.udev.extraRules = ''
    SUBSYSTEM=="drm", \
      KERNEL=="card[0-9]*", \
      SUBSYSTEMS=="pci", \
      KERNELS=="0000:00:02.0", \
      DRIVERS=="i915", \
      SYMLINK+="dri/intel-igpu"
  '';
  environment.sessionVariables = {
    KWIN_DRM_DEVICES = "/dev/dri/intel-igpu";
    KWIN_RENDER_NODES = "";
  };

  hardware.nvidia = {
    modesetting.enable = true;

    powerManagement = {
      enable = true;
      finegrained = true;
    };

    open = false;

    gsp.enable = false;
    moduleParams.nvidia.NVreg_EnableGpuFirmware = 0;

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
