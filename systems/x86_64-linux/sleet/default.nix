{pkgs, ...}: {
  networking.hostName = "sleet";
  imports = [
    ./hardware-configuration.nix
  ];

  mods.display.plasma = { enable = true; defaultx11 = true; };

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
}