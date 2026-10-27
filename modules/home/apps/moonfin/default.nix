{ pkgs, namespace, ... }: {
  home.packages = [ pkgs.${namespace}.moonfin ];

  persistif.directories = [
    ".local/share/org.moonfin.linux"
    "Documents/Moonfin/DB"
  ];
}