{ lib, config, pkgs, ... }:
let
  cfg = config.mods.ios-drivers;
in
{
  options = {
    mods.ios-drivers = {
      enable = lib.mkEnableOption "iOS Drivers";
    };
  };
  config = lib.mkIf (cfg.enable) {
    services.usbmuxd = {
      enable = true;
    };
    environment.systemPackages = with pkgs; [
      libimobiledevice
      ifuse
    ];
  };
}
