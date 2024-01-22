{ sysargs, ... }: {
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${sysargs.username} = {
    isNormalUser = true;
    description = "Brad Hesson";
    extraGroups = [ "networkmanager" "wheel" ];
  };
}
