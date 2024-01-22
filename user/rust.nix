{ sysargs, flakes, pkgs, ... }:
let
  fenix = flakes.fenix.packages.${sysargs.system};
in
{
  home.packages = [
    fenix.stable.defaultToolchain
    fenix.stable.rust-analyzer
    pkgs.gcc
  ];
}
