let srcs = import ./nix;
in { pkgs ? srcs.pkgs }:
let ssb-server = pkgs.lib.setPrio 8 srcs.ssb-server;
in {
  inherit ssb-server;
  inherit (srcs) omnia install-omnia stark-cli oracle-suite;
}
