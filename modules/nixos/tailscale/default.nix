{
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
  };
  persistif.directories = [
    "/var/lib/tailscale"
  ];
}
