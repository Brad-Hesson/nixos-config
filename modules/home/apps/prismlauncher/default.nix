{ pkgs, lib, config, ... }:
let cfg = config.mods.apps.prismlauncher; in {
  options = {
    mods.apps.prismlauncher.enable = lib.mkEnableOption "Prism Minecraft Launcher";
  };
  config = lib.mkIf (cfg.enable) {
    home.packages = with pkgs; [ prismlauncher ];
    persistif.directories = [
      ".local/share/PrismLauncher"
    ];
  };
}
