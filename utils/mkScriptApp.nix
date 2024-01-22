pkgs: name: prog: {
  type = "app";
  program = "${pkgs.writeScriptBin name prog}/bin/${name}";
}
