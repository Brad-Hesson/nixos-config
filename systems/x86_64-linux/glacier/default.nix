{ pkgs, ... }: {
  networking.hostName = "glacier";
  imports = [
    ./hardware-configuration.nix
    ./nvidia.nix
    ./display.nix
    ./network.nix
  ];

  impermanence = {
    enable = true;
    persistPath = "/persist";
    snapshotPath = "zpool/root@blank";
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

  environment.systemPackages = [ ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Home Manager
  home-manager.backupFileExtension = "backup";

  # ZFS
  networking.hostId = "3072eb80";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound.
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "24.11"; # Did you read the comment?
}
