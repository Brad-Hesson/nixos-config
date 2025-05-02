{
  # Enable sound with pipewire.
  security.rtkit.enable = true;
  services = {
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };

  environment.persistence."/persist".users.bhesson.directories = [
    ".local/state/wireplumber"
  ];


}
