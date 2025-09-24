{pkgs, ...}: {
  home.packages = [pkgs.parsec-bin];

  persistif.directories = [
    ".parsec"
  ];
}