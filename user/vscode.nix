{ pkgs, ... }: {
  programs.vscode.enable = true;
  home.packages = with pkgs; [ nil nixpkgs-fmt ];

  home.persistence."/persist/home/bhesson".directories = [
    ".vscode"
    ".config/Code/User"
  ];
}
