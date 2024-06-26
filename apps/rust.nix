{
  home-manager.users.bhesson = { pkgs, ... }: {
    home.persistence."/persist/home/bhesson".directories = [
      ".cargo"
      ".rustup"
    ];
  };
}
