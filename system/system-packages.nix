{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    home-manager
    gparted
    wineWowPackages.stable
    jq
    nh
    protonup
  ];

  environment.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS =
      "\${HOME}/.steam/root/compatibilitytools.d";
  };

  programs.steam.enable = true;
  programs.gamemode.enable = true;

  virtualisation.spiceUSBRedirection.enable = true;

  # Labjack usb permissions
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="0cd5", ATTR{idProduct}=="0007", ENV{ID_SECURITY_TOKEN}="1", GROUP="wheel"
  '';

}
