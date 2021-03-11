let
  srcs = import ./nix/srcs.nix;
in
{ pkgs ? srcs.pkgs }:
with pkgs;
let
  ssb-server = lib.setPrio 9 srcs.ssb-server;
in {
  inherit ssb-server;
  inherit (srcs) omnia install-omnia stark-cli;
}
