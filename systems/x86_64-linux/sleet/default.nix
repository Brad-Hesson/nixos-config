{ pkgs, ... }: {
  networking.hostName = "sleet";
  imports = [
    ./hardware-configuration.nix
    ./ms-surface.nix
    ./nvidia.nix
    ./secure-boot.nix
    ./remote.nix
  ];

  mods = {
    display.plasma = { enable = true; defaultX11 = false; };
    apps.steam.enable = true;
    bootSplash = { enable = true; theme = "bgrt"; };
    ios-drivers = { enable = true; };
  };

  impermanence = {
    enable = true;
    persistPath = "/persist";
    snapshotPath = "tank/local/root@blank";
    pool = "tank";
  };
  persistif.directories = [
    "/var/lib/nixos" # persists uids and gids
  ];

  users.users.bhesson = {
    isNormalUser = true;
    description = "Brad Hesson";
    extraGroups = [ "networkmanager" "wheel" "docker" "dialout" "systemd-journal" ];
    hashedPassword = "$y$j9T$c1qsrXwEJdndbCCmnfoUn/$RzG1bgFBSTjWNFrl/H3aV99bWZFU2rXttY9uXQgdsI9";
  };

  # ZFS
  networking.hostId = "00000000";

  system.stateVersion = "24.11";
}
