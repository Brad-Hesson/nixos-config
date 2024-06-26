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


}
