{ pkgs, config, ... }: {
  # persist the logs
  persistif.directories = [ "/var/log/journal" ];

  # make the machine-id static so that logs are continuous between boots
  # this script just hashes the hostname so it remains constant, but different between systems
  environment.etc."machine-id".source = pkgs.runCommandLocal "machine-id" { } ''
    echo "${config.networking.hostName}" | md5sum | cut -f1 -d" " > $out
  '';
}
