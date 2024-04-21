{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    tailscale
  ];
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };
  environment.persistence."/persist".directories = [
    "/var/lib/tailscale"
  ];
}
