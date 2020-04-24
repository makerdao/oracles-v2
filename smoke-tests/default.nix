let srcs = import ../nix/srcs.nix; in

{ pkgs ? srcs.makerpkgs.pkgs
, nodepkgs ? srcs.nodepkgs { inherit pkgs; }
}@args:

pkgs.mkShell rec {
  name = "oracle-smoke-test-shell";
  buildInputs = with pkgs; with import ./.. args; [
    install-omnia ssb-server
    procps go-ethereum dapp
    nodepkgs.tap-xunit
  ];

  TEST_DIR = toString ./.;

  NIX_PATH="nixpkgs=${pkgs.path}";

  shellHook = ''
    smokeTest() {
      (cd "$TEST_DIR" && {
        mkdir -p test-results
        ./test.sh | tee >(tap-xunit > test-results/smoke-test.xml)
      } )
    }
  '';
}
