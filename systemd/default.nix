{ stdenv, lib, makeWrapper, shellcheck
, glibcLocales, coreutils, gettext, omnia, ssb-server
}:

stdenv.mkDerivation rec {
  name = "install-omnia-service-${version}";
  version = lib.fileContents ../omnia/version;
  src = ./.;

  passthru.runtimeDeps =  [
    coreutils gettext
  ];
  nativeBuildInputs = [ makeWrapper shellcheck ];

  buildPhase = "true";
  installPhase = let
    path = lib.makeBinPath passthru.runtimeDeps;
    locales = lib.optionalString (glibcLocales != null)
      "--set LOCALE_ARCHIVE \"${glibcLocales}\"/lib/locale/locale-archive";
  in ''
    mkdir -p $out/bin
    cp -t $out/bin *.service install-omnia-service

    wrapProgram "$out/bin/install-omnia-service" \
      --set PATH "${path}" \
      --set OMNIA_PATH "${omnia}/bin/omnia" \
      --set SSB_PATH "${ssb-server}/bin/ssb-server" \
      ${locales}
  '';

  doCheck = true;
  checkPhase = ''
    shellcheck -x install-omnia-service
  '';

  meta = with lib; {
    description = "Installer script for Omnia service";
    homepage = https://github.com/makerdao/oracles-v2;
    license = licenses.gpl3;
    inherit version;
  };
}
