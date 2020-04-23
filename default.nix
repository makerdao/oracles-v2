let srcs = import ./nix/srcs.nix; in

{ pkgs ? srcs.makerpkgs.pkgs
, nodepkgs ? srcs.nodepkgs { inherit pkgs; }
, setzer-mcdSrc ? srcs.setzer-mcd
}: with pkgs;

let
  ssb-server = nodepkgs.ssb-server.override {
    buildInputs = [ gnumake nodepkgs.node-gyp-build ];
  };

  setzer-mcd = callPackage setzer-mcdSrc {};
in rec {
  inherit ssb-server;
  omnia = callPackage ./omnia { inherit ssb-server setzer-mcd; };
  install-omnia = callPackage ./systemd { inherit ssb-server omnia; };
}
