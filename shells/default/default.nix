{ pkgs, mkShell, ... }: mkShell {
  # Create your shell
  packages = with pkgs; [
    nil
    nixpkgs-fmt
  ];
}
