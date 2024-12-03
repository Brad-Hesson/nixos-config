{ pkgs, config, ... }: {
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

  # persist the logs
  environment.persistence."/persist".directories = [
    "/var/log/journal"
  ];

  # make the machine-id static so that logs are continuous between boots
  # this script just hashes the hostname so it remains constant, but different between systems
  environment.etc."machine-id".source = pkgs.runCommandLocal "machine-id" { } ''
    echo "${config.networking.hostName}" | md5sum | cut -f1 -d" " > $out
  '';

}
