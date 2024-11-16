{ pkgs, ... }: {
  home.packages = with pkgs; [
    prusa-slicer
    vlc
    qdirstat
    prismlauncher
    jdk17_headless
    inotify-tools
    nix-output-monitor
    # (import ../packages/lychee-slicer.nix pkgs)
  ];


  home.persistence."/persist/home/bhesson" = {
    directories = [
      ".local/share/PrismLauncher"
      {
        directory = ".local/share/Steam";
        method = "symlink";
      }
      ".config/PrusaSlicer"
    ];
  };

}
