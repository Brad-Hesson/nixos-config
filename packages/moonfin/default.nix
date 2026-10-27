# A flake-managed Moonfin package. Requires the `moonfin-release` flake input.
# See README.md for how to add the input to your existing flake.
{ lib
, stdenv
, fetchurl
, appimageTools
, inputs
}:
let
  # This is a *locked flake input*, not an impure network request at evaluation.
  release = builtins.fromJSON (builtins.readFile inputs.moonfin-release.outPath);
  version = lib.removePrefix "v" release.tag_name;

  assetName =
    if stdenv.hostPlatform.system == "x86_64-linux" then
      "Moonfin_Linux_v${version}.AppImage"
    else if stdenv.hostPlatform.system == "aarch64-linux" then
      "Moonfin_LinuxARM64_v${version}.AppImage"
    else
      throw "Moonfin: unsupported platform ${stdenv.hostPlatform.system}";

  matches = builtins.filter (asset: asset.name == assetName) release.assets;
  asset =
    if builtins.length matches == 1 then
      builtins.head matches
    else
      throw "Moonfin ${version}: expected one release asset named ${assetName}";

  # GitHub's release-asset API provides `digest = "sha256:<64 hex chars>"`.
  # fetchurl accepts the hexadecimal hash via its sha256 attribute.
  digest = asset.digest or null;
  sha256 =
    if builtins.isString digest
      && lib.hasPrefix "sha256:" digest
      && builtins.match "[0-9a-f]{64}" (lib.removePrefix "sha256:" digest) != null
    then
      lib.removePrefix "sha256:" digest
    else
      throw "Moonfin ${version}: GitHub release asset ${assetName} is missing a valid SHA-256 digest";

  src = fetchurl {
    url = asset.browser_download_url;
    inherit sha256;
  };

  appimageContents = appimageTools.extract {
    pname = "moonfin";
    inherit version src;
  };
in
appimageTools.wrapType2 {
  pname = "moonfin";
  inherit version src;

  # These are required by the upstream AppImage but are not bundled in it.
  extraPkgs = pkgs: with pkgs; [
    libepoxy
    libxv
  ];

  # Upstream names both the Wayland application and desktop file org.moonfin.linux.
  # Copy its actual launcher and icon out of the AppImage.
  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/org.moonfin.linux.desktop \
      $out/share/applications/org.moonfin.linux.desktop
    install -Dm444 ${appimageContents}/usr/share/icons/hicolor/512x512/apps/org.moonfin.linux.png \
      $out/share/icons/hicolor/512x512/apps/org.moonfin.linux.png
  '';

  meta = {
    description = "Moonfin Jellyfin and Emby desktop client";
    homepage = "https://github.com/Moonfin-Client/Moonfin-Core";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "moonfin";
  };
}
