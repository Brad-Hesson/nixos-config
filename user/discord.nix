{ pkgs, ... }: {
  home.packages = with pkgs; [ discord ];
  home.persistence."/persist/home/bhesson".directories = [
    ".config/discord"
  ];
}
