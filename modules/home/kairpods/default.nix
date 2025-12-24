{ inputs, ... }: {
  imports = [ inputs.kairpods.homeModules.default ];

  services.kairpods.enable = true;
}
