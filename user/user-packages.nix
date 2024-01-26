{ pkgs, ... }: {
  home.packages = with pkgs; [
    steam
    prusa-slicer
    thunderbird
    discord
    vlc
    qdirstat
    prismlauncher
    jdk17_headless
    # (import ../packages/lychee-slicer.nix pkgs)
  ];

  home.persistence."/persist/home/bhesson".directories = [
    ".local/share/PrismLauncher"
    ".local/share/Steam"
  ];
}
