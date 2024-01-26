{ pkgs, ... }: {
  home.packages = with pkgs; [
    steam
    prusa-slicer
    thunderbird
    vlc
    qdirstat
    prismlauncher
    jdk17_headless
    # (import ../packages/lychee-slicer.nix pkgs)
  ];
}
