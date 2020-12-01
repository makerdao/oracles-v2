let
  sources = import ../nix/sources.nix;
  srcs = import ../nix/srcs.nix;
in

{ pkgs ? import sources.nixpkgs {}
, makerpkgs ? import sources.makerpkgs {}
, nodepkgs ? srcs.nodepkgs { inherit pkgs; }
}@args:

let
  oracles = import ./.. args;
  inherit (import sources.nixpkgs {}) mitmproxy;
in

pkgs.mkShell rec {
  name = "oracle-smoke-test-shell";
  buildInputs = with pkgs; [
    procps jq mitmproxy
    go-ethereum

    nodepkgs.tap-xunit

    makerpkgs.dapp

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
      cp "$tap" "$RESULTS_DIR/$name/"
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

    _runTest() {
      local ecode=0
      "''${@:2}"
      ecode=$?
      xunit "$1" logs/*.tap || true
      return $ecode
    }

    testSmoke() { _runTest smoke sh -c 'mkdir -p logs && "$1" > logs/smoke.tap' _ "$SMOKE_TEST"; }
    testE2E() { _runTest e2e "$E2E_TEST" "$@"; }
    updateE2E() { _runTest e2e-update "$E2E_TEST" --update "$@"; }
  '';
}
