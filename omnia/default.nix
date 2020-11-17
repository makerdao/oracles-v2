{ stdenv, makeWrapper, runCommand, lib, glibcLocales
, coreutils, bash, parallel, bc, jq, gnused, datamash, gnugrep
, ssb-server, ethsign, seth, setzer-mcd }:

let
  deps = [
    coreutils bash parallel bc jq gnused datamash gnugrep
    ssb-server ethsign seth setzer-mcd
  ];
in

stdenv.mkDerivation rec {
  name = "omnia-${version}";
  version = lib.fileContents ./lib/version;
  src = ./.;

  buildInputs = deps;
  nativeBuildInputs = [ makeWrapper ];
  passthru.runtimeDeps = buildInputs;

  buildPhase = let
    path = lib.makeBinPath passthru.runtimeDeps;
    locales = lib.optionalString (glibcLocales != null)
      "--set LOCALE_ARCHIVE \"${glibcLocales}\"/lib/locale/locale-archive";
  in ''
    find ./bin -type f | while read -r x; do
      patchShebangs "$x"
      wrapProgram "$x" \
        --set PATH "$out/bin:${path}" \
        ${locales}
    done
  '';

  installPhase = ''
    mkdir -p $out/{bin,lib}
    cp -r -t $out/bin ./bin
    cp -r -t $out/lib ./lib
  '';

  doCheck = true;
  checkPhase = ''
    cp ${../tests/lib/tap.sh} ./tap.sh
    find . -name '*_test*' -or -path "*/test/*.sh" | while read -r x; do
      patchShebangs "$x"
      $x
    done
  '';

  meta = with lib; {
    description = "Omnia is a smart contract oracle client";
    homepage = https://github.com/makerdao/oracles-v2;
    license = licenses.gpl3;
    inherit version;
  };
}
