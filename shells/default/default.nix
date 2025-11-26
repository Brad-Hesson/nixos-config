{ inputs, mkShell, system, ... }: mkShell {
  shellHook = ''
    ${inputs.brad-utils.lib.${system}.vscodeSettingsHook {}}
  '';
}
