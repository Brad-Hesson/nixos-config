{ inputs, ... }: {
  programs.alacritty = {
    enable = true;
    settings = {
      general.import = [
        "${inputs.alacritty-themes}/themes/linux.toml"
      ];
      keyboard.bindings = [
        {
          key = "F11";
          action = "ToggleFullscreen";
        }
      ];
    };
  };
  xdg.desktopEntries."Alacritty" = {
    name = "Alacritty";
    genericName = "Terminal";
    comment = "A fast, cross-platform, OpenGL terminal emulator";
    exec = "alacritty";
    icon = "Alacritty";
    terminal = false;
    categories = [ "System" "TerminalEmulator" ];
    startupNotify = true;
    settings = {
      TryExec = "alacritty";
      StartupWMClass = "Alacritty";
      Keywords = "terminal;shell;prompt;command;commandline;cmd;";
    };
    actions.New = {
      name = "New Terminal";
      exec = "alacritty";
    };
  };
  programs.plasma = {
    configFile = {
      "kdeglobals"."General" = {
        TerminalApplication = "alacritty";
        TerminalService = "Alacritty.desktop";
      };
    };
  };
}
