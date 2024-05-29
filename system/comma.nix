{ sysargs, ... }: {
  home-manager.users.${sysargs.username} = { pkgs, ... }: {
    home.persistence."/persist/home/${sysargs.username}" = {
      directories = [
        ".cache/nix-index"
      ];
    };
    home.packages = with pkgs; [ comma ];
  };
}
