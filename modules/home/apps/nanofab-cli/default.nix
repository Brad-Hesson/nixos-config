{ inputs, system, ... }: {
  home.packages = [
    inputs.nanofab-cli.packages.${system}.default
  ];
}
