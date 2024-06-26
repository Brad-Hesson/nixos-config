{
  home-manager.users.bhesson = { pkgs, ... }: {
    home.persistence."/persist/home/bhesson" = {
      directories = [
        ".cache/nix-index"
      ];
    };
    home.packages = with pkgs; [ comma ];
  };
}