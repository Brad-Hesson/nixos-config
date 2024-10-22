{ lib, inputs, config, ... }: {
  imports = [ inputs.nur.hmModules.nur ];

  programs.firefox = {
    enable = true;
    profiles.default = {
      extensions = with config.nur.repos.rycee.firefox-addons; [
        bitwarden
        ublock-origin
        plasma-integration
      ];
    };
  };
  # make touchscreen scrolling work
  # NOTE: only works if programs.bash.enable = true, meaning
  #       that home-manager is managing the shell
  home.sessionVariables = lib.trivial.throwIfNot (config.programs.bash.enable == true)
    "firefox.nix: home-manager setting `programs.bash.enable == true` must be
        set in order to configure firefox for touchscreens"
    {
      MOZ_USE_XINPUT2 = "1";
    };
  persistif.directories = [ ".mozilla" ];
}
