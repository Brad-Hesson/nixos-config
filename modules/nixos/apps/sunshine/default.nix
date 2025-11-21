{ pkgs, lib, config, ... }:
let cfg = config.mods.apps.sunshine; in {
  options = {
    mods.apps.sunshine.enable = lib.mkEnableOption "Sunshine Game Streaming";
  };
  config = lib.mkIf (cfg.enable) {
    services.sunshine = {
      enable = true;
      autoStart = false;
      capSysAdmin = true;
      openFirewall = true;
    };
  };
}
