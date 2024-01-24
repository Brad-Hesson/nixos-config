flakes: { username, hostname, system, userModules, systemModules, ... }@sysargs:
let
  pkgs = import flakes.nixpkgs {
    inherit system;
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
  homeConfigurations.${username} = flakes.home-manager.lib.homeManagerConfiguration {
    extraSpecialArgs = { inherit flakes sysargs; };
    inherit pkgs;
    modules = userModules ++ [{
      home.username = username;
      home.homeDirectory = "/home/${username}";
      home.stateVersion = "23.05";
    }];
  };

  apps.${system} =
    let mkScriptApp = import ./mkScriptApp.nix pkgs; in
    {
      default = mkScriptApp "rebuild" ''
        sudo nixos-rebuild switch --flake . && \
        home-manager switch --flake . && \
        echo "Rebuild Successful"
      '';
      hm = mkScriptApp "hm" ''
        echo $@
        home-manager switch --flake . && \
        echo "Rebuild Successful"
      '';
      test = mkScriptApp "test" ''
        sudo nixos-rebuild dry-activate --flake .
        echo "building the home configuration..."
        home-manager build --no-out-link --flake . && \
        echo "would activate the configuration..."
      '';
      gc = mkScriptApp "gc" ''
        sudo nix-collect-garbage
      '';
      history = mkScriptApp "history" ''
        case $1 in
          hm | home-manager | h | home)
            nix profile history --profile ~/.local/state/nix/profiles/home-manager
          ;;
          sys | system | s)
            nix profile history --profile /nix/var/nix/profiles/system
          ;;
          *)
            echo "----------[ System ]----------"
            nix profile history --profile /nix/var/nix/profiles/system
            echo ""
            echo "-------[ Home Manager ]-------"
            nix profile history --profile ~/.local/state/nix/profiles/home-manager
          ;;
        esac
      '';
      diff = mkScriptApp "diff" ''
        case $1 in
          hm | home-manager | h | home)
            nix profile diff-closures --profile ~/.local/state/nix/profiles/home-manager
          ;;
          sys | system | s)
            nix profile diff-closures --profile /nix/var/nix/profiles/system
          ;;
          *)
            echo "----------[ System ]----------"
            nix profile diff-closures --profile /nix/var/nix/profiles/system
            echo ""
            echo "-------[ Home Manager ]-------"
            nix profile diff-closures --profile ~/.local/state/nix/profiles/home-manager
          ;;
        esac
      '';
      wipe = mkScriptApp "wipe" ''
        case $1 in
          hm | home-manager | h | home)
            echo "Home Manager:"
            nix-env --delete-generations --profile ~/.local/state/nix/profiles/home-manager $2
            echo ""
            echo "Profile:"
            nix-env --delete-generations --profile ~/.local/state/nix/profiles/profile $2
          ;;
          sys | system | s)
            echo "System:"
            sudo nix-env --delete-generations --profile /nix/var/nix/profiles/system $2
          ;;
          *)
            echo "System:"
            sudo nix-env --delete-generations --profile /nix/var/nix/profiles/system $1
            echo ""
            echo "Home Manager:"
            nix-env --delete-generations --profile ~/.local/state/nix/profiles/home-manager $1
            echo ""
            echo "Profile:"
            nix-env --delete-generations --profile ~/.local/state/nix/profiles/profile $1
          ;;
        esac
      '';

    };
}
