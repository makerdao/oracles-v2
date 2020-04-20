let srcs = (import <nixpkgs> {}).callPackage ../nix/srcs.nix {}; in

{ pkgs ? srcs.makerpkgs.pkgs
, nodepkgs ? import ../nix/nodepkgs.nix { inherit pkgs; }
, ssb-caps ? null
}@args:

pkgs.mkShell rec {
  name = "oracle-smoke-test-shell";
  buildInputs = with pkgs; [
    (import ./.. args).install-omnia
    procps go-ethereum dapp
    nodepkgs."tap-xunit-2.4.1"
  ];

  NIX_PATH="nixpkgs=${pkgs.path}";

  TEST_DIR = toString ./.;

  shellHook = ''
    smokeTest() {
      (cd "$TEST_DIR" && {
        mkdir -p test-results
        ./test.sh | tee >(tap-xunit > test-results/smoke-test.xml)
      } )
    }
  '';
}
