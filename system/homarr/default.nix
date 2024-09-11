{ yarn-berry, fetchFromGitHub, stdenvNoCC, cacert, ... }:
let
  pname = "homarr";
  version = "0.15.4";
  src = fetchFromGitHub {
    owner = "ajnart";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-MDD7dTK85+K7wjxHVVeFCpKZrcsWRvAtdStHCcFkGDk=";
  };
in
stdenvNoCC.mkDerivation {
  inherit pname version src;

  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = "sha256-HYfV1xJ1xXRluFoOqR4u9S4PeP4sP7rMEx2+8gk7KbQ=";

  nativeBuildInputs = [ yarn-berry ];

  supportedArchitectures = builtins.toJSON {
    os = [ "darwin" "linux" ];
    cpu = [ "arm" "arm64" "ia32" "x64" ];
    libc = [ "glibc" "musl" ];
  };

  NODE_EXTRA_CA_CERTS = "${cacert}/etc/ssl/certs/ca-bundle.crt";

  dontPatchShebangs = true;

  configurePhase = ''
    runHook preConfigure

    export HOME="$NIX_BUILD_TOP"
    export YARN_ENABLE_TELEMETRY=0
    yarn config set enableGlobalCache false
    yarn config set supportedArchitectures --json "$supportedArchitectures"

    runHook postConfigure
  '';
  buildPhase = ''
    runHook preBuild

    yarn install --immutable
    cp .env.example .env
    yarn build
    yarn db:migrate

    runHook postBuild
  '';
  installPhase = ''
    cp -r ./. $out
  '';
}
