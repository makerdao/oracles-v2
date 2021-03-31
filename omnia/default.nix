{ stdenv, makeWrapper, lib, glibcLocales
, coreutils, bash, parallel, bc, jq, gnused, datamash, gnugrep
, ssb-server, ethsign, seth, setzer-mcd, stark-cli }:

stdenv.mkDerivation rec {
  name = "omnia-${version}";
  version = lib.fileContents ./version;
  src = ./.;

  passthru.runtimeDeps =  [
    coreutils bash parallel bc jq gnused datamash gnugrep
    ssb-server ethsign seth setzer-mcd stark-cli
  ];
  buildInputs = passthru.runtimeDeps;
  nativeBuildInputs = [ makeWrapper ];

  buildPhase = "true";
  installPhase = let
    path = lib.makeBinPath passthru.runtimeDeps;
    locales = lib.optionalString (glibcLocales != null)
      "--set LOCALE_ARCHIVE \"${glibcLocales}\"/lib/locale/locale-archive";
  in ''
    mkdir -p $out/{bin,lib}
    cp -r -t $out/lib ./*

    cat > $out/bin/omnia <<EOF
    #!/usr/bin/env bash
    (cd $out/lib
      exec ./omnia.sh
    )
    EOF

    chmod +x $out/bin/omnia

    wrapProgram "$out/bin/omnia" \
      --argv0 omnia \
      --set PATH "${path}" \
      ${locales}
  '';

  doCheck = true;
  checkPhase = ''
    cp ${../tests/lib/tap.sh} ./tap.sh
    find ./test -name '*.sh' | while read -r x; do
      patchShebangs $x
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
