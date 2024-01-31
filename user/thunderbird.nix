{ pkgs, ... }: {
  home.packages = with pkgs; [
    thunderbird
  ];
  home.persistence."/persist/home/bhesson".directories = [
    ".thunderbird"
  ];
}
