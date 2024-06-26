{ sysargs, ... }: {
  networking.hostName = sysargs.hostname;
  networking.networkmanager.enable = true;
  networking.hostId = "00000000";

  environment.persistence."/persist".directories = [
    "/etc/NetworkManager/system-connections"
  ];

  networking.firewall.allowedTCPPorts = [ 8081 7071 ];
}
