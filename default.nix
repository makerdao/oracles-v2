let
  srcs = import ./nix/srcs.nix;
in

{ pkgs ? srcs.pkgs
, gofer ? (if builtins.pathExists ./gofer then import ./gofer {} else null)
}: with pkgs;

let
  ssb-server = lib.setPrio 9 srcs.ssb-server;
  omnia = srcs.omnia { inherit gofer; };
  install-omnia = srcs.install-omnia { inherit gofer; };
in {
  inherit ssb-server omnia install-omnia;
}
