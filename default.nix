let
  sources = import ./nix/sources.nix;
in

{ pkgs ? import sources.dapptools {}
, srcs ? import ./nix/srcs.nix { inherit pkgs; }
, nodepkgs ? srcs.nodepkgs
, setzer-mcdSrc ? sources.setzer-mcd
}: with pkgs;

let
  ssb-server = lib.setPrio 9 (nodepkgs.ssb-server.override {
    buildInputs = [ gnumake nodepkgs.node-gyp-build ];
  });

  setzer-mcd = callPackage setzer-mcdSrc {};
in rec {
  inherit ssb-server;
  omnia = callPackage ./omnia { inherit ssb-server setzer-mcd; };
  install-omnia = callPackage ./systemd { inherit ssb-server omnia; };
}
