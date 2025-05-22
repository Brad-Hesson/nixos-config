{ fetchFromGitHub
, stdenv
, ...
}: stdenv.mkDerivation {
  name = "k_plasma_boot_screen";
  src = fetchFromGitHub {
    owner = "K-Plasma-Project";
    repo = "K-plasma-boot-screen";
    rev = "a432b93";
    hash = "sha256-jCP7HGgw5tK0FkRU6U/P5FxV3kZ5IGibSEUh+kK0Q5o=";
  };
  installPhase = ''
    mkdir -p $out/share/plymouth/themes
    cp -r "k-plasma Plymouth (Dark)/k-plasma-dark" $out/share/plymouth/themes
    cp -r "k-plasma Plymouth (Light)/k-plasma-light" $out/share/plymouth/themes
    sed -i "s|/usr|$out|g" $out/share/plymouth/themes/k-plasma-dark/k-plasma-dark.plymouth
    sed -i "s|/usr|$out|g" $out/share/plymouth/themes/k-plasma-light/k-plasma-light.plymouth
  '';
}
