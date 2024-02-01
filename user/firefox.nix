{ config, flakes, ... }: {
  imports = [ flakes.nur.hmModules.nur ];
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
  home.sessionVariables = {
    MOZ_USE_XINPUT2 = "1";
  };
  home.persistence."/persist/home/bhesson".directories = [
    ".mozilla"
  ];
}
