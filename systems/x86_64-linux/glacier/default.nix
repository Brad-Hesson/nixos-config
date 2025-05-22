{ pkgs, ... }: {
  networking.hostName = "glacier";
  imports = [
    ./hardware-configuration.nix
    ./nvidia.nix
  ];

  mods.display.plasma = { enable = true; defaultX11 = false; };
  mods.apps.steam.enable = true;
  mods.plymouth.enable = false;

  impermanence = {
    enable = true;
    persistPath = "/persist";
    snapshotPath = "zpool/root@blank";
  };
  persistif.directories = [
    "/var/lib/nixos" # persists uids and gids
    "/etc/ssh"
  ];

  nix.settings.trusted-users = [ "bhesson" ];
  users.users.bhesson = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "dialout" ];
    hashedPassword = "$y$j9T$c1qsrXwEJdndbCCmnfoUn/$RzG1bgFBSTjWNFrl/H3aV99bWZFU2rXttY9uXQgdsI9";
    packages = with pkgs; [
      tree
      prismlauncher
      nh
      nix-output-monitor
      wget
    ];
  };

  # Boot
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # Home Manager
  home-manager.backupFileExtension = "backup";

  # ZFS
  networking.hostId = "3072eb80";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  system.stateVersion = "24.11";
}
