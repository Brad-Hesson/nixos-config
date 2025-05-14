{ lib, config, ... }:
let
  cfg = config.mods.display.plasma;
in
{
  options = {
    mods.display.plasma = {
      enable = lib.mkEnableOption "plasma display";
      defaultX11 = lib.mkEnableOption "default to x11 rather than wayland";
    };
  };
  config = lib.mkIf (cfg.enable) {
    mods.hardware.network.ports = [{ from = 1714; to = 1764; }]; # Ports for KDE Connect
    services.xserver.enable = true;
    services.displayManager.sddm.enable = true;
    services.displayManager.sddm.wayland.enable = true;
    services.displayManager.defaultSession = lib.mkIf (cfg.defaultX11) "plasmax11";
    services.desktopManager.plasma6.enable = true;
    services.xserver.xkb.layout = "us";
  };
}
