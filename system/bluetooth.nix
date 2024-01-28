{ pkgs, ... }: {
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  environment.systemPackages = [ pkgs.bluez ];

  environment.persistence."/persist".directories = [
    "/var/lib/bluetooth"
  ];

}
