{pkgs, ...}: {
  home.packages = [pkgs.kdePackages.krdc];

  persistif.directories = [
    ".local/share/krdc"
  ];
}