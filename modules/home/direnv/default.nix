{
  programs.direnv = {
    enable = true;
    enableBashIntegration = true; # see note on other shells below
    nix-direnv.enable = true;
  };

  persistif.directories = [ ".local/share/direnv/allow" ];
}
