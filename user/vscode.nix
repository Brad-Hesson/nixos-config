{ pkgs, ... }: {
  programs.vscode = {
    enable = true;
    userSettings = {
      extensions.autoUpdate = false;
      extensions.autoCheckUpdates = false;
      update.mode = "none";
      window.zoomLevel = 1;

      nix.enableLanguageServer = true;
      # ---------- [ nil ] ----------
      nix.serverPath = "nil";
      nix.serverSettings = {
        nil = {
          formatting = { command = [ "nixpkgs-fmt" ]; };
        };
      };
      # ---------- [ nixd ] ----------
      # nix.serverPath = "nixd";
      # nix.serverSettings.nixd = {
      #   formatting.command = "nixpkgs-fmt";
      #   eval = {
      #     target = {
      #       args = [ "-f" "default.nix" ];
      #       installable = "homeConfigurations.bhesson";
      #     };
      #     depth = 10;
      #   };
      #   options = {
      #     enable = false;
      #     target.installable = ".#nixosConfigurations.bhesson.options";
      #   };
      # };
    };
    extensions = with pkgs.vscode-extensions; [
      jnoortheen.nix-ide
      rust-lang.rust-analyzer
      usernamehw.errorlens
    ];
  };
  home.packages = with pkgs; [ nil nixpkgs-fmt ];
}
