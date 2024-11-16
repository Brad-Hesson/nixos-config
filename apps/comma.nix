{ flakes, ... }: {
  home-manager.users.bhesson = { pkgs, ... }: {
    imports = [ flakes.nix-index-database.hmModules.nix-index ];

    # optional to also wrap and install comma
    programs.nix-index-database.comma.enable = true;

  };
}
