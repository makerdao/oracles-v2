let
  srcs = import ./nix/srcs.nix;
  sources = import ./nix/sources.nix;
in

{ pkgs ? import sources.nixpkgs {}
, makerpkgs ? import sources.makerpkgs {}
, nodepkgs ? srcs.nodepkgs { inherit pkgs; }
, setzer-mcdSrc ? sources.setzer-mcd
, gofer ? srcs.gofer
}: with makerpkgs.pkgs;

let
  ssb-server = lib.setPrio 9 (nodepkgs.ssb-server.override {
    buildInputs = [ gnumake nodepkgs.node-gyp-build ];
  });

  setzer-mcd = callPackage setzer-mcdSrc {};
in rec {
  inherit ssb-server;
  omnia = callPackage ./omnia { inherit ssb-server setzer-mcd gofer; };
  install-omnia = callPackage ./systemd { inherit ssb-server omnia; };
}
