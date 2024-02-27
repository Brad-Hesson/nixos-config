{ pkgs, ... }: {
  home.packages = with pkgs; [
    steam
    prusa-slicer
    vlc
    qdirstat
    prismlauncher
    jdk17_headless
    inotify-tools
    # (import ../packages/lychee-slicer.nix pkgs)
  ];

  home.persistence."/persist/home/bhesson" = {
    directories = [
      ".local/share/PrismLauncher"
      {
        directory = ".local/share/Steam";
        method = "symlink";
      }
    ];
  };

}
