{ lib, inputs, config, pkgs, ... }:
let
  cfg = config.impermanence;
  # the type of the forwarded impermanence option, extracted from the impermanence module
  persistOptionType = (pkgs.callPackage inputs.impermanence.nixosModules.impermanence {
    utils = { };
    # The extracted option type has deeply nested options that copy their defaults from options in the top
    # level of the def (eg. enableDebugging, hideMounts). Thus, we need to set the internal top level def
    # to *our* top level def, so that the option defaults are correct.
    # See https://github.com/nix-community/impermanence/blob/e337457502571b23e449bf42153d7faa10c0a562/nixos.nix#L197
    # In the above example, the ${name} it is given is `persistif` because that is the attr that this type is being applied to (below).
    # For it to find a value there, we need to populate that attr with *our* top level config
    config.environment.persistence.persistif = config.persistif;
  }).options.environment.persistence.type.nestedTypes.elemType;
in
{
  imports = [ inputs.impermanence.nixosModules.impermanence ];
  options = {
    persistif = lib.mkOption { default = { }; type = persistOptionType; };
    impermanence.enable = lib.mkEnableOption "impermanence";
    impermanence.persistPath = lib.mkOption { type = lib.types.path; description = "The path to the persisted directory"; example = "/persist"; };
    impermanence.snapshotPath = lib.mkOption { type = lib.types.str; description = "The path of the blanking snapshot"; example = "zpool/root@blank"; };
  };
  config = lib.mkIf (cfg.enable) {
    # forward the peristif config to the impermanence config
    environment.persistence."" = config.persistif;

    # since we overwrite the storage path here, we don't need to name it above
    persistif.persistentStoragePath = cfg.persistPath;

    # persisted values may be necessary for boot
    fileSystems.${cfg.persistPath}.neededForBoot = true;

    # reset to the provided snapshot on each boot
    boot.initrd.postResumeCommands = lib.mkAfter ''
      echo "Rolling back to ZFS snapshot `${cfg.snapshotPath}`"
      zfs rollback -r ${cfg.snapshotPath}
    '';

    # this is needed to allow the home module to set `allowOther`, so that sudo can access the mounts
    programs.fuse.userAllowOther = true;
  };
}
