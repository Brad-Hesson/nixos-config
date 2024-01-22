{ flakes, ... }: {
  imports = [ flakes.plasma-manager.homeManagerModules.plasma-manager ];
  programs.plasma = {
    enable = true;
    workspace = {
      theme = "breeze-dark";
      clickItemTo = "select";
    };
  };
}
