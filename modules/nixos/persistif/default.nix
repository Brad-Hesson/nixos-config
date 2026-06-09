{ lib, inputs, config, pkgs, ... }:
let
  cfg = config.impermanence;
  mkIfElse = p: yes: no: lib.mkMerge [
    (lib.mkIf p yes)
    (lib.mkIf (!p) no)
  ];
in
{
  imports = [
    inputs.impermanence.nixosModules.impermanence
    (lib.mkAliasOptionModule [ "persistif" ] [ "environment" "persistence" cfg.persistPath ])
  ];
  options = {
    impermanence.enable = lib.mkEnableOption "impermanence";
    impermanence.persistPath = lib.mkOption { type = lib.types.path; description = "The path to the persisted directory"; example = "/persist"; };
    impermanence.snapshotPath = lib.mkOption { type = lib.types.str; description = "The path of the blanking snapshot"; example = "zpool/root@blank"; };
    impermanence.pool = lib.mkOption { type = lib.types.str; description = "The ZFS pool name"; example = "zpool"; };
  };
  config = mkIfElse cfg.enable
    {
      # persisted values may be necessary for boot
      fileSystems.${cfg.persistPath}.neededForBoot = true;
      boot.zfs.forceImportRoot = false;

      # rollback to the provided snapshot on each boot
      # boot.initrd.postDeviceCommands = lib.mkAfter ''
      #   echo "Rolling back to ZFS snapshot '${cfg.snapshotPath}'"
      #   zfs rollback -r ${cfg.snapshotPath}
      #   echo "Rollback complete"
      # '';
      boot.initrd.systemd.services.zfs-rollback = {
        wantedBy = [ "initrd.target" ];
        after = [ "zfs-import-${cfg.pool}.service" ];
        requires = [ "zfs-import-${cfg.pool}.service" ];
        before = [ "sysroot.mount" ];
        unitConfig.DefaultDependencies = "no";
        path = [ pkgs.zfs ];
        serviceConfig.Type = "oneshot";
        script = ''
          echo "Rolling back to ZFS snapshot '${cfg.snapshotPath}'"
          zfs rollback -r ${cfg.snapshotPath}
          echo "Rollback complete"
        '';
      };

      # this is needed to allow the home module to set `allowOther`, so that sudo can access the mounts
      programs.fuse.userAllowOther = true;
    }
    {
      persistif.enable = false;
    };
}
