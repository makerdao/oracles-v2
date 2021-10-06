{ stdenv, lib, makeWrapper, shellcheck, glibcLocales, coreutils, gettext, jq, omnia, ssb-server, oracle-suite }:

stdenv.mkDerivation rec {
  name = "install-omnia-${version}";
  version = lib.fileContents ../version;
  src = ./.;

  passthru.runtimeDeps = [ coreutils gettext jq ];
  nativeBuildInputs = [ makeWrapper shellcheck ];

  buildPhase = "true";
  installPhase = let
    path = lib.makeBinPath passthru.runtimeDeps;
    locales = lib.optionalString (glibcLocales != null) ''--set LOCALE_ARCHIVE "${glibcLocales}"/lib/locale/locale-archive'';
    omniaConf = ../omnia/config;
  in ''
    mkdir -p $out/{bin,share}
    cp -t $out/bin install-omnia
    cp -t $out/share *.service *.json *-updates ${omniaConf}/*

    wrapProgram "$out/bin/install-omnia" \
      --prefix PATH : "${path}" \
      --set SHARE_PATH "$out/share" \
      --set OMNIA_PATH "${omnia}/bin/omnia" \
      --set OMNIA_LIB_PATH "${omnia}/lib" \
      --set OMNIA_CONF_PATH "$out/share" \
      --set GOFER_PATH "${oracle-suite}/bin/gofer" \
      --set SPIRE_PATH "${oracle-suite}/bin/spire" \
      --set SPLITTER_PATH "${oracle-suite}/bin/rpc-splitter" \
      --set SSB_PATH "${ssb-server}/bin/ssb-server" \
      ${locales}
  '';

  doCheck = true;
  checkPhase = ''
    shellcheck -x install-omnia
  '';

  meta = with lib; {
    description = "Installer script for Omnia service";
    homepage = "https://github.com/makerdao/oracles-v2";
    license = licenses.gpl3;
    inherit version;
  };
}
