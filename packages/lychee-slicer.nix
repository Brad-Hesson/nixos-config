{ appimageTools
, fetchurl
, runCommandLocal
, ...
}:
let
  version = "5.4.3";
  sha256 = "sha256-qi5YXWYIZf3Nf6zXEudzhgWdhchQfD66yAEb5P5WXEQ=";
  
  appImage = fetchurl {
    url = "https://mango-lychee.nyc3.cdn.digitaloceanspaces.com/LycheeSlicer-${version}.AppImage";
    inherit sha256;
  };
  pname = "lycheeslicer";
  extracted = appimageTools.extractType2 {
    inherit pname version;
    src = appImage;
  };
  wrapped = appimageTools.wrapAppImage {
    name = pname;
    src = extracted;
    extraPkgs = _: [ ];
  };
in
runCommandLocal "${pname}-${version}" { } ''
  mkdir -p $out/bin
  ln -s ${wrapped}/bin/${pname} $out/bin/${pname}

  mkdir -p $out/share/applications
  sed "s/Exec=.*/Exec=${pname} %U/" ${extracted}/${pname}.desktop > $out/share/applications/${pname}.desktop

  ln -s ${extracted}/usr/share/icons $out/share/icons
  mkdir -p $out/share/pixmaps
  ln -s ${extracted}/${pname}.png $out/share/pixmaps/${pname}.png
''
