{pkgs, ...}: {
  home.packages = [pkgs.kdePackages.krdc];

  persistif = {
    directories = [
      ".local/share/krdc"
      ".config/freerdp"
    ];
    files = [
      ".config/krdcrc"
    ];
  };
}
