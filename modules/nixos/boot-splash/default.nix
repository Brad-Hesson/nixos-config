{ pkgs, config, lib, ... }:
let cfg = config.mods.bootSplash; in {
  options = {
    mods.bootSplash.enable = lib.mkEnableOption "Enable Plymouth";
    mods.bootSplash.theme = lib.mkOption {
      default = "bgrt";
      type = lib.types.str;
      description = "Splash screen theme.";
    };
  };
  config = lib.mkIf (cfg.enable) {
    fonts.packages = with pkgs; [ inter ];
    boot = {
      plymouth = {
        enable = true;
        theme = cfg.theme;
        themePackages = [
          (pkgs.callPackage ./k-plasma-boot-screen.nix { })
          pkgs.adi1090x-plymouth-themes
        ];
      };
      # Enable "Silent boot"
      consoleLogLevel = 3;
      initrd.verbose = false;
      kernelParams = [
        "quiet"
        "splash"
        "boot.shell_on_fail"
        "udev.log_priority=3"
        "rd.systemd.show_status=auto"
        "plymouth.use-simpledrm"
      ];
      # Hide the OS choice for bootloaders.
      # It's still possible to open the bootloader list by pressing any key
      # It will just not appear on screen unless a key is pressed
      loader.timeout = 0;
    };
  };
}
