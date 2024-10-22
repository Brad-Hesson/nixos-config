{
  # Easiest to use and most distros use this by default
  networking.networkmanager.enable = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ ];
  networking.firewall.allowedUDPPorts = [ ];

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
}
