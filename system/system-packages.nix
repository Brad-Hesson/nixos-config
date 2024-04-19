{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    home-manager
    gparted
    wineWowPackages.stable
    jq
    nh
  ];
}
