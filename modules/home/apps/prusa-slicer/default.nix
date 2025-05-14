{ pkgs, lib, config, ... }:
let cfg = config.mods.apps.prusaslicer; in {
  options = {
    mods.apps.prusaslicer.enable = lib.mkEnableOption "Prusa Slicer";
  };
  config = lib.mkIf (cfg.enable) {
    home.packages = with pkgs; [ prusa-slicer ];
    persistif.directories = [
      ".config/PrusaSlicer"
    ];
  };
}
