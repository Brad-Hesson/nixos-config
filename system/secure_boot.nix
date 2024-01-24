{ lib, pkgs, flakes, ... }: {
  # See https://github.com/nix-community/lanzaboote
  imports = [ flakes.lanzaboote.nixosModules.lanzaboote ];

  # Lanzaboote currently replaces the systemd-boot module.
  # This setting is usually set to true in configuration.nix
  # generated at installation time. So we force it to false
  # for now.
  boot.loader.systemd-boot.enable = true;
  # boot.loader.systemd-boot.enable = lib.mkForce false;
  # boot.lanzaboote = {
  #   enable = true;
  #   pkiBundle = "/etc/secureboot";
  #   configurationLimit = 3;
  # };

  environment.systemPackages = with pkgs; [
    # For debugging and troubleshooting Secure Boot.
    sbctl
  ];
}
