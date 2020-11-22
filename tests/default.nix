let
  srcs = import ../nix/srcs.nix;
  sources = import ../nix/sources.nix;
in

{ pkgs ? import sources.nixpkgs {}
, makerpkgs ? import sources.makerpkgs {}
, nodepkgs ? srcs.nodepkgs { inherit pkgs; }
}@args:

let oracles = import ./.. args; in

pkgs.mkShell rec {
  name = "oracle-smoke-test-shell";
  buildInputs = with pkgs; [
    procps jq mitmproxy
    go-ethereum

    nodepkgs.tap-xunit

    makerpkgs.pkgs.dapp

    oracles.omnia
    oracles.install-omnia
  ] ++ oracles.omnia.runtimeDeps;

  RESULTS_DIR = "${toString ./.}/test-results";
  SMOKE_TEST = toString ./smoke/test;
  E2E_TEST = toString ./e2e/test;

  shellHook = ''
    _xunit() {
      local name="$1"
      local tap="$2"
      mkdir -p "$RESULTS_DIR/$name"
      tap-xunit < "$tap" \
        > "$RESULTS_DIR/$name/results.xml"
      mv "$tap" "$RESULTS_DIR/$name/"
    }

    xunit() {
      local name="$1"
      local tests=("''${@:2}")
      if [[ $tests ]]; then
        for test in "''${tests[@]}"; do
          _xunit "$name-''${test%.*}" "$test"
        done
      else
        local output="$(mktemp tap-XXXXXXXX).tap"
        tee "$output"
        _xunit "$name" "$output"
      fi
    }

    testSmoke() { "$SMOKE_TEST" | xunit smoke; }
    testE2E() { "$E2E_TEST" "$@"; xunit e2e *.tap; }
    updateE2E() { "$E2E_TEST" --update "$@"; xunit e2e-update *.tap; }
  '';
}
