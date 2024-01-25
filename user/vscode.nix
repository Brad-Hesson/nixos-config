{ pkgs, ... }: {
  programs.vscode.enable = true;
  home.packages = with pkgs; [ nil nixpkgs-fmt ];
}
