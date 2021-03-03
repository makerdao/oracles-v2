{ stdenv, makeWrapper, runCommand, lib, glibcLocales
, coreutils, bash, parallel, bc, jq, gnused, datamash, gnugrep
, ssb-server, ethsign, seth, setzer-mcd, stark-cli }:

let
  inherit (builtins) pathExists;
  tapsh = if (pathExists ./tap.sh) then ./tap.sh else ../tests/lib/tap.sh;
  deps = [
    coreutils bash parallel bc jq gnused datamash gnugrep
    ssb-server ethsign seth setzer-mcd stark-cli
  ];
in

stdenv.mkDerivation rec {
  name = "omnia-${version}";
  version = lib.fileContents ./lib/version;
  src = ./.;

  buildInputs = deps;
  nativeBuildInputs = [ makeWrapper ];
  passthru.runtimeDeps = buildInputs;

  buildPhase = ''
    find ./bin -type f | while read -r x; do patchShebangs "$x"; done
  '';

  doCheck = true;
  checkPhase = ''
    cp ${tapsh} ./tap.sh
    find . -name '*_test*' -or -path "*/test/*.sh" | while read -r x; do
      patchShebangs "$x"; $x
    done
  '';

  installPhase = let
    path = lib.makeBinPath passthru.runtimeDeps;
    locales = lib.optionalString (glibcLocales != null)
      "--set LOCALE_ARCHIVE \"${glibcLocales}\"/lib/locale/locale-archive";
  in ''
    mkdir -p $out
    cp -r ./lib $out/lib
    cp -r ./bin $out/bin
    cp -r ./config $out/config
    find $out/bin -type f | while read -r x; do
      wrapProgram "$x" \
        --prefix PATH : "$out/bin:${path}" \
        ${locales}
    done
  '';


  meta = with lib; {
    description = "Omnia is a smart contract oracle client";
    homepage = https://github.com/makerdao/oracles-v2;
    license = licenses.gpl3;
    inherit version;
  };
}
