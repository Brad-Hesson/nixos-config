{ flakes, mkShell, system, ... }: mkShell {
  shellHook = ''
    ${flakes.brad-utils.lib.${system}.vscodeSettingsHook {}}
  '';
}
