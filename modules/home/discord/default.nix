{ pkgs, ... }: {
  home.packages = with pkgs; [ discord ];
  persistif.directories = [
    ".config/discord"
  ];
}
