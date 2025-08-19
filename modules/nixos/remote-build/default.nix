{ config, ... }: {
  persistif.directories = [ "/root/.ssh" "/etc/ssh" ];
  # TODO: hardcoded username
  nix.settings.trusted-users = [ "bhesson" ];
}