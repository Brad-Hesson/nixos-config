{ pkgs, ... }: {
  home.packages = with pkgs; [ discord ];
  persistif.directories = [
    ".config/discord"
  ];
  xdg.desktopEntries.discord = {
    name = "Discord";
    genericName = "Instant Messenger";
    comment = "All-in-one cross-platform voice and text chat for gamers";
    exec = "Discord %u";
    icon = "discord";
    categories = [ "Network" "InstantMessaging" ];
    mimeType = [ "x-scheme-handler/discord" ];
    settings.StartupWMClass = "discord";
  };
}
