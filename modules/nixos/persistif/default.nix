{ lib, inputs, config, ... }:
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
  };
  config = mkIfElse cfg.enable
    {
      # persisted values may be necessary for boot
      fileSystems.${cfg.persistPath}.neededForBoot = true;

      # rollback to the provided snapshot on each boot
      boot.initrd.postResumeCommands = lib.mkAfter ''
        echo "Rolling back to ZFS snapshot '${cfg.snapshotPath}'"
        zfs rollback -r ${cfg.snapshotPath}
        echo "Rollback complete"
      '';

      # this is needed to allow the home module to set `allowOther`, so that sudo can access the mounts
      programs.fuse.userAllowOther = true;
    }
    {
      persistif.enable = false;
    };
}
