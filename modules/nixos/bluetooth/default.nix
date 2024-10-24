{ pkgs, ... }: {
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  environment.systemPackages = [ pkgs.bluez ];

  persistif.directories = [
    "/var/lib/bluetooth"
  ];

}
