{
  description = "Nixos Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nur.url = "github:nix-community/NUR";
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:pjones/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    impermanence.url = "github:nix-community/impermanence";
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = flakes: (import ./utils/mkOutputs.nix) flakes {
    username = "bhesson";
    hostname = "nixos";
    system = "x86_64-linux";
    userModules = [
      ./user/user-packages.nix
      ./user/impermanence.nix
      ./user/bash.nix
      ./user/kde.nix
      ./user/git.nix
    ];
    systemModules = [
      ./apps/discord.nix
      ./apps/rust.nix
      ./apps/direnv.nix
      ./apps/thunderbird.nix
      ./apps/firefox.nix
      ./apps/vscode.nix
      ./apps/comma.nix
      ./system/hardware-configuration.nix
      ./system/system-packages.nix
      ./system/display-manager.nix
      ./system/impermanence.nix
      ./system/localization.nix
      ./system/secure_boot.nix
      ./system/ms-surface.nix
      ./system/networking.nix
      ./system/bluetooth.nix
      ./system/tailscale.nix
      ./system/printing.nix
      ./system/docker.nix
      ./system/nvidia.nix
      ./system/sound.nix
      ./system/users.nix
      ./system/homarr/homarr.nix
    ];
  };
}
