{
  description = "Nixos Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nur.url = "github:nix-community/NUR";
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.3.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:pjones/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    impermanence.url = "github:nix-community/impermanence";
  };

  outputs = flakes: (import ./utils/mkOutputs.nix) flakes {
    username = "bhesson";
    hostname = "nixos";
    system = "x86_64-linux";
    userModules = [
      ./user/user-packages.nix
      ./user/firefox.nix
      ./user/discord.nix
      ./user/vscode.nix
      ./user/bash.nix
      ./user/rust.nix
      ./user/kde.nix
      ./user/git.nix
    ];
    systemModules = [
      ./system/hardware-configuration.nix
      ./system/system-packages.nix
      ./system/display-manager.nix
      ./system/impermanence.nix
      ./system/localization.nix
      ./system/secure_boot.nix
      ./system/ms-surface.nix
      ./system/networking.nix
      ./system/bluetooth.nix
      ./system/printing.nix
      ./system/nvidia.nix
      ./system/sound.nix
      ./system/users.nix
    ];
  };
}
