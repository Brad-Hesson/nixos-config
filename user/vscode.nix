{ pkgs, flakes, ... }: {
  imports = [ flakes.impermanence.nixosModules.home-manager.impermanence ];
  programs.vscode.enable = true;
  programs.direnv = {
    enable = true;
    enableBashIntegration = true; # see note on other shells below
    nix-direnv.enable = true;
  };
  home.packages = with pkgs; [ nil nixpkgs-fmt ];

  home.persistence."/persist/home/bhesson".directories = [
    ".vscode"
    ".config/Code/User"
    ".local/share/direnv/allow"
  ];
}
