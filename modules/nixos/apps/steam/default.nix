{ pkgs, lib, config, ... }:
let cfg = config.mods.apps.steam; in {
  options = {
    mods.apps.steam.enable = lib.mkEnableOption "Steam";
  };
  config = lib.mkIf (cfg.enable) {
    programs.steam.enable = true;
  };
}
