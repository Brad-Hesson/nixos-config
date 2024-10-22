{ inputs, lib, config, ... }: {
  imports = [ ];
  home.stateVersion = "24.05";
  programs.bash.enable = true;

  persistif.directories = [ "Desktop" "Pictures" ];
  
  programs.git = {
    enable = true;
    userName = "Brad Hesson";
    userEmail = "brad.hesson@outlook.com";
  };
}
