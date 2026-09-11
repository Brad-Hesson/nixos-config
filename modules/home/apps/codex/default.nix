{pkgs, ...}: {
  home.packages = [pkgs.codex];

  persistif.directories = [
    ".codex"
  ];
}