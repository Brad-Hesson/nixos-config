{ inputs, mkShell, pkgs, ... }: mkShell {
  shellHook = ''
    ${(inputs.brad-utils.mkLib pkgs).vscodeSettingsHook {}}
  '';
}
