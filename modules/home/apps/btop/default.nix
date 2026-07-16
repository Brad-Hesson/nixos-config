{ pkgs, ... }: {
  home.packages = with pkgs; [ btop-cuda ];

  persistif.directories = [
    ".config/btop"
  ];
}