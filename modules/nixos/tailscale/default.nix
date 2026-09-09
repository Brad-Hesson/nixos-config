{
  services = {
    tailscale = {
      enable = true;
      useRoutingFeatures = "both";
    };
    resolved.enable = true;
  };
  persistif.directories = [
    "/var/lib/tailscale"
  ];
  # fix for issue with dns ordering
  systemd.services.tailscaled = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };
  networking.networkmanager.dns = "systemd-resolved";
}
