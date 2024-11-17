flakes: { username, hostname, system, userModules, systemModules, ... }@sysargs:
let
  pkgs = import flakes.nixpkgs {
    inherit system;
    # Package ‘zfs-kernel-2.2.6-6.11.4’ is marked as broken
    config.allowBroken = true;
    config.allowUnfree = true;
  };
in
{
  nixosConfigurations.${hostname} = flakes.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit flakes sysargs; };
    inherit pkgs;
    modules = systemModules ++ [
      {
        nix.settings.experimental-features = [ "nix-command" "flakes" ];
        system.stateVersion = "23.11";
      }
      flakes.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = { inherit flakes sysargs; };
        home-manager.users.${username} = {
          imports = userModules;
          home.username = username;
          home.homeDirectory = "/home/${username}";
          home.stateVersion = "23.05";
        };
      }
    ];
  };
  apps.${system} =
    let mkScriptApp = import ./mkScriptApp.nix pkgs; in
    {
      default = mkScriptApp "rebuild" ''
        sudo nixos-rebuild switch --flake . && \
        echo "Rebuild Successful"
      '';
      test = mkScriptApp "test" ''
        sudo nixos-rebuild dry-activate --flake .
      '';
      gc = mkScriptApp "gc" ''
        sudo nix-collect-garbage
      '';
      history = mkScriptApp "history" ''
        nix profile history --profile /nix/var/nix/profiles/system
      '';
      diff = mkScriptApp "diff" ''
        nix profile diff-closures --profile /nix/var/nix/profiles/system
      '';
      wipe = mkScriptApp "wipe" ''
        sudo nix-env --delete-generations --profile /nix/var/nix/profiles/system $1
      '';

    };
}
