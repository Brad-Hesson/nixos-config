{ pkgs, ... }: {
  services = {
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
    printing = {
      enable = true;
      drivers = with pkgs; [
        cups-filters
        cups-browsed
      ];
    };
    resolved.settings.Resolve.MulticastDNS = false;
  };


  persistif.directories = [
    "/var/lib/cups"
  ];
}
