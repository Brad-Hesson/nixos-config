{
  nix.distributedBuilds = true;
  nix.buildMachines = [{
    hostName = "bhesson@glacier";
    system = "x86_64-linux";
    protocol = "ssh-ng";
    maxJobs = 6;
    speedFactor = 100;
    supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
    mandatoryFeatures = [ ];
  }];
  nix.settings = {
    # get remote to use substitutes from it's own cache, and not just the local cache
    builders-use-substitutes = true;
    # check the remote's cache for substitutes rather than rebuilding locally
    extra-substituters = [
      "ssh-ng://bhesson@glacier?trusted=true&priority=10"
    ];
  };
}
