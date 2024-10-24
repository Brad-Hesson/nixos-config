{ lib, config, ... }:
let
  cfg = config.mods.display;
in
{
  options = {
    mods.display.plasma = {
      enable = lib.mkEnableOption "plasma display";
      defaultx11 = lib.mkEnableOption "default to x11 rather than wayland";
    };
  };
  config = lib.mkIf (cfg.plasma.enable) {
    services.xserver.enable = true;
    services.displayManager.sddm.enable = true;
    services.displayManager.defaultSession = lib.mkIf (cfg.plasma.defaultx11) "plasmax11";
    services.desktopManager.plasma6.enable = true;
    services.xserver.xkb.layout = "us";
  };
}
