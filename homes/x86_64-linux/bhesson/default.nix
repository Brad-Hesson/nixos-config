{ inputs, lib, config, ... }: {
  imports = [ ];
  programs.bash.enable = true;

  persistif.directories = [ "Desktop" "Pictures" ".ssh" "Code" ];

  programs.git = {
    enable = true;
    userName = "Brad Hesson";
    userEmail = "brad.hesson@outlook.com";
  };

  mods.apps.prismlauncher.enable = true;

  home.stateVersion = "24.05";
}
