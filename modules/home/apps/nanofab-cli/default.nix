{ inputs, system, ... }: {
  home.packages = [
    inputs.nanofab-cli.packages.${system}.default
  ];

  persistif.directories = [
    ".config/nanofab-cli"
  ];

}
