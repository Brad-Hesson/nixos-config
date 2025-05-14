{ pkgs, ... }: {
  networking.hostName = "sleet";
  imports = [
    ./hardware-configuration.nix
    ./ms-surface.nix
    ./nvidia.nix
    ./secure-boot.nix
  ];

  mods.display.plasma = { enable = true; defaultX11 = true; };
  mods.apps.steam.enable = true;

  impermanence = {
    enable = true;
    persistPath = "/persist";
    snapshotPath = "tank/local/root@blank";
  };
  persistif.directories = [
    "/var/lib/nixos" # persists uids and gids
  ];

  users.users.bhesson = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPassword = "$y$j9T$c1qsrXwEJdndbCCmnfoUn/$RzG1bgFBSTjWNFrl/H3aV99bWZFU2rXttY9uXQgdsI9";
    packages = with pkgs; [
      tree
      prismlauncher
      nh
      nix-output-monitor
      wget
    ];
  };

  # ZFS
  networking.hostId = "00000000";

  # Enable CUPS to print documents.
  services.printing.enable = true;

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

  system.stateVersion = "24.11";
}
