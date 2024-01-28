{ sysargs, ... }: {
  networking.hostName = sysargs.hostname;
  networking.networkmanager.enable = true;
  networking.hostId = "00000000";

  environment.persistence."/persist" = {
    directories = [
      "/etc/NetworkManager/system-connections"
    ];
    users.bhesson.directories = [
      ".local/share/kwalletd"
    ];
  };
}
