{ sysargs, ... }: {
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${sysargs.username} = {
    isNormalUser = true;
    description = "Brad Hesson";
    extraGroups = [ "networkmanager" "wheel" "docker" "dialout" "systemd-journal" ];
    hashedPasswordFile = "/persist/etc/users/bhesson";
  };

  environment.persistence."/persist".users.${sysargs.username}.directories = [
    "Code"
    "Desktop"
    ".ssh"
  ];
  environment.persistence."/persist".directories = [
    "/var/lib/nixos"
  ];
}
