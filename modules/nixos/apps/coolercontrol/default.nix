{ lib, config, pkgs, ... }:
let cfg = config.mods.apps.coolercontrol; in {
  options = {
    mods.apps.coolercontrol.enable = lib.mkEnableOption "Cooler Control";
  };
  config = lib.mkIf (cfg.enable) {
    programs.coolercontrol = {
      enable = true;
      nvidiaSupport = true;
    };
  };
}
