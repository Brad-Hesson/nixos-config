{ lib, osConfig, ... }: {
  # Cannot be enabled directly
  # If enabled at the system level, then instructs the persistance of the user steam folder
  config = lib.mkIf (osConfig.mods.apps.steam.enable) {
    persistif.directories = [
      {
        directory = ".local/share/Steam";
        method = "symlink";
      }
    ];
  };
}
