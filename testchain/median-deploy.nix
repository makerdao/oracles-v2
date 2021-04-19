{ pkgs ? import <nixpkgs> {} }:
let
  medianScript = ./bin/median-deploy;
  medianFetchGit = pkgs.fetchgit {
    url = "https://github.com/makerdao/testchain-medians.git";
    sha256 = "1rimgmxlfxymmjyx3yz0lp30zin7jrf4ygrj6ydvdwjgw3fmnwgh";
    rev = "1fe9f7bcaa41dacdcf8bb2527e007e186e3e3c09";
    deepClone = true;
    fetchSubmodules = true;
  };
  wrapperPath = pkgs.lib.makeBinPath ([
    pkgs.jq
    pkgs.bash
    pkgs.dapp
    pkgs.seth
  ]);
in pkgs.stdenv.mkDerivation {
  name = "median-deploy";

  buildInputs = [
    pkgs.makeWrapper
    pkgs.solc-static-versions.solc_0_5_12
    pkgs.dapp
  ];

  unpackPhase = ''
    cp -r ${medianFetchGit}/* ./
    cp ${medianScript} ./
  '';

  buildPhase = ''
    # Beacuse of https://github.com/NixOS/docker/issues/34 we can't use "make build" directly.
  	dapp --use "${pkgs.solc-static-versions.solc_0_5_12}/bin/solc" build
  '';

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/src
    cp out/dapp.sol.json $out/src/dapp.sol.json
    cp ${medianScript} $out/bin/median-deploy
    chmod u+x $out/bin/median-deploy
    wrapProgram $out/bin/median-deploy --set DAPP_JSON $out/src/dapp.sol.json --prefix PATH : "${wrapperPath}"
  '';
}
