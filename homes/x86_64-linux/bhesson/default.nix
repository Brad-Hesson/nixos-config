{ ... }: {
  imports = [ ];
  programs.bash.enable = true;

  persistif.directories = [ "Desktop" "Pictures" ".ssh" "Code" ];

  home.packages = with pkgs; [
    vlc
    qdirstat
  ];

  programs = {
    git = {
      enable = true;
      userName = "Brad Hesson";
      userEmail = "brad.hesson@outlook.com";
    };
    gh = {
      enable = true;
      gitCredentialHelper = {
        enable = true;
      };
    };
  };

  mods.apps.prismlauncher.enable = true;
  mods.apps.prusaslicer.enable = true;

  home.stateVersion = "24.05";
}
