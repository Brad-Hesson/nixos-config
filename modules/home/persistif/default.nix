{ lib, osConfig, ... }:
let
  osCfg = osConfig.impermanence;
in
{
  imports = [ (lib.mkAliasOptionModule [ "persistif" ] [ "home" "persistence" osCfg.persistPath ]) ];
  config = lib.mkIf (!osCfg.enable) {
    persistif.enable = false;
  };
}
