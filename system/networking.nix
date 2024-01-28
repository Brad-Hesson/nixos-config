{ sysargs, ... }: {
  networking.hostName = sysargs.hostname;
  networking.networkmanager.enable = true;
  networking.hostId = "00000000";
}
