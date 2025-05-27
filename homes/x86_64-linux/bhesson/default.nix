{ pkgs, ... }: {
  imports = [ ];
  programs.bash.enable = true;

  persistif.directories = [ "Desktop" "Pictures" ".ssh" "Code" ];

  home.packages = with pkgs; [
    vlc
    qdirstat
    gparted
    nh
    nix-output-monitor
    wget
  ];

  mods = {
    apps.prismlauncher.enable = true;
    apps.prusaslicer.enable = true;
  };

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

  home.stateVersion = "24.05";
}
