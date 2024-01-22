{ sysargs, ... }: {
  networking.hostName = sysargs.hostname;
  networking.networkmanager.enable = true;
}
