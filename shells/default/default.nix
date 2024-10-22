{ pkgs, mkShell, ... }: mkShell {
  # Create your shell
  packages = with pkgs; [
    nixpkgs-fmt
    nixd
  ];
}
