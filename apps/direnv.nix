{
  home-manager.users.bhesson = { ... }: {
    programs.direnv = {
      enable = true;
      enableBashIntegration = true; # see note on other shells below
      nix-direnv.enable = true;
    };
    home.persistence."/persist/home/bhesson".directories = [
      ".local/share/direnv/allow"
    ];
  };
}
