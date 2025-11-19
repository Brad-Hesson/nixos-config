{ pkgs, ... }: {
  networking.hostName = "sleet";
  imports = [
    ./hardware-configuration.nix
    ./ms-surface.nix
    ./nvidia.nix
    ./secure-boot.nix
  ];

  users.users.bhesson = {
    isNormalUser = true;
    description = "Brad Hesson";
    extraGroups = [ "networkmanager" "wheel" "docker" "dialout" "systemd-journal" ];
    hashedPassword = "$y$j9T$c1qsrXwEJdndbCCmnfoUn/$RzG1bgFBSTjWNFrl/H3aV99bWZFU2rXttY9uXQgdsI9";
  };

  nix.buildMachines = [{
    hostName = "bhesson@glacier";
    system = "x86_64-linux";
    protocol = "ssh-ng";
    # if the builder supports building for multiple architectures, 
    # replace the previous line by, e.g.
    # systems = ["x86_64-linux" "aarch64-linux"];
    maxJobs = 6;
    speedFactor = 2;
    supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
    mandatoryFeatures = [ ];
  }];
  nix.distributedBuilds = true;
  # optional, useful when the builder has a faster internet connection than yours
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';

  # ZFS
  networking.hostId = "00000000";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  system.stateVersion = "24.11";
}
