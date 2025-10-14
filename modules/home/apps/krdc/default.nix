{pkgs, ...}: {
  home.packages = [pkgs.kdePackages.krdc];

  persistif.files = [
    ".config/krdcrc"
  ];
}