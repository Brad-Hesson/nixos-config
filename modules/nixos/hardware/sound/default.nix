{
  # Enable sound.
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    audio.enable = true;
  };
  security.rtkit.enable = true;
}
