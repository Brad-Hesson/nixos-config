{
  # Easiest to use and most distros use this by default
  networking.networkmanager.enable = true;

  # Open ports in the firewall.
  networking.firewall =
    let
      both = [{ from = 1714; to = 1764; }]; # KDE Connect
    in
    {
      allowedTCPPortRanges = both ++ [ ];
      allowedUDPPortRanges = both ++ [ ];
    };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
}
