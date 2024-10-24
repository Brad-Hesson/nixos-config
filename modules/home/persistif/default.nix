{ lib, inputs, config, osConfig, pkgs, ... }:
let
  # we automatically activate if the system persist option is activated, no sense having them differ
  osCfg = osConfig.impermanence;
  # the type of the forwarded impermanence option, extracted from the impermanence module
  persistOptionType = (pkgs.callPackage inputs.impermanence.nixosModules.home-manager.impermanence {
    config.home.impermanence.persistif = config.persistif;
  }).options.home.persistence.type.nestedTypes.elemType;
in
{
  imports = [ inputs.impermanence.nixosModules.home-manager.impermanence ];
  options = {
    # this is where modules can set their persistence dirs and files, the option is
    # is forwarded to the impermanence module
    persistif = lib.mkOption {
      default = { };
      type = persistOptionType;
    };
  };
  config = lib.mkIf (osCfg.enable) {
    # forward the peristif config to the impermanence config
    home.persistence."" = config.persistif;

    # since we overwrite the storage path here, we don't need to name it above
    persistif.persistentStoragePath = "${osCfg.persistPath}/home/${config.snowfallorg.user.name}";

    # this is needed to allow sudo to access the mounts
    persistif.allowOther = true;
  };
}