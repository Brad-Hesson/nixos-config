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
}
