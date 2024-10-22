{ pkgs, ... }: {
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
  ];

  impermanence = {
    enable = true;
    persistPath = "/persist";
    snapshotPath = "zpool/root@blank";
  };

  persistif.directories = [
    "/var/lib/nixos" # persists uids and gids
    "/var/log/journal" # persists the journalctl log
  ];
  environment.etc."machine-id".text = "a820625fc1684eff85b35e5e198a3a76";


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
