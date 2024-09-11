{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.homarr;
  src = import ./default.nix pkgs;
in
{
  options = {
    services.homarr = {
      enable = mkEnableOption "Homarr";

      dataDir = mkOption {
        type = types.str;
        default = "/var/lib/homarr";
        description = "The directory where Homarr stores its data files.";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Open ports in the firewall for the Homarr web interface
        '';
      };

      user = mkOption {
        type = types.str;
        default = "homarr";
        description = "User account under which Homarr runs.";
      };

      group = mkOption {
        type = types.str;
        default = "homarr";
        description = "Group under which Homarr runs.";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.homarr = {
      description = "Homarr";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.yarn-berry pkgs.rsync pkgs.bash ];

      preStart = ''
        if [ ! -d "${cfg.dataDir}" ]; then
          mkdir -p ${cfg.dataDir}
          rsync -r --exclude node_modules ${src}/ ${cfg.dataDir}
          ln -s ${src}/node_modules ${cfg.dataDir}/node_modules
          chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}
          chmod -R +w ${cfg.dataDir}
        fi
      '';

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = pkgs.writeScript "homarr-execstart" ''
          #!/usr/bin/env bash
          cd ${cfg.dataDir}
          exec yarn start
        '';
        Restart = "on-failure";
        PermissionsStartOnly = true;
      };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ 3000 ];
    };

    users.users = mkIf (cfg.user == "homarr") {
      homarr = {
        group = cfg.group;
        home = cfg.dataDir;
        uid = 267;
      };
    };

    users.groups = mkIf (cfg.group == "homarr") {
      homarr.gid = 267;
    };
  };
}

