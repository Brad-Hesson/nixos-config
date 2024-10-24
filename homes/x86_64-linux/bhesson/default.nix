{ inputs, lib, config, ... }: {
  imports = [ ];
  programs.bash.enable = true;

  persistif.directories = [ "Desktop" "Pictures" ];
  
  programs.git = {
    enable = true;
    userName = "Brad Hesson";
    userEmail = "brad.hesson@outlook.com";
  };
  
  home.stateVersion = "24.05";
}
