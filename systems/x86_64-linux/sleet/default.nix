{ pkgs, ... }: {
  networking.hostName = "sleet";
  imports = [
    ./hardware-configuration.nix
    ./ms-surface.nix
    ./nvidia.nix
    ./secure-boot.nix
  ];

  mods = {
    display.plasma = { enable = true; defaultX11 = true; };
    apps.steam.enable = true;
    bootSplash = { enable = true; theme = "bgrt"; };
  };

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
    description = "Brad Hesson";
    extraGroups = [ "networkmanager" "wheel" "docker" "dialout" "systemd-journal" ];
    hashedPassword = "$y$j9T$c1qsrXwEJdndbCCmnfoUn/$RzG1bgFBSTjWNFrl/H3aV99bWZFU2rXttY9uXQgdsI9";
    packages = with pkgs; [
      tree
      nh
      nix-output-monitor
    ];
  };

  # ZFS
  networking.hostId = "00000000";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  system.stateVersion = "24.11";
}
