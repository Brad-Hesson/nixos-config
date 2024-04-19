{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    tailscale
  ];
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };
}
