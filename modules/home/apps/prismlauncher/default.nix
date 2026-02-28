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
    home.activation.setPrismJava = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      cfg="$HOME/.local/share/PrismLauncher/prismlauncher.cfg"
      if [ -f "$cfg" ]; then
        ${pkgs.gnused}/bin/sed -i "s|^JavaPath=.*|JavaPath=${pkgs.jdk21}/bin/java|" "$cfg"
      fi
    '';
  };
}
