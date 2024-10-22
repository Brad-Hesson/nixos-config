{ pkgs, ... }: {
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
    ./nvidia.nix
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
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    hashedPassword = "$y$j9T$c1qsrXwEJdndbCCmnfoUn/$RzG1bgFBSTjWNFrl/H3aV99bWZFU2rXttY9uXQgdsI9";
    packages = with pkgs; [
      tree
      prismlauncher
    ];
  };

  environment.systemPackages = with pkgs; [
    nh
    nix-output-monitor
    wget
  ];
}
