let
  inherit (builtins) map filter listToAttrs attrValues isString currentSystem;
  dappPkgs = import sources.dapptools {};
  inherit (dappPkgs) fetchgit;
  inherit (dappPkgs.lib.strings) removePrefix;

  getName = x:
   let
     parse = drv: (builtins.parseDrvName drv).name;
   in if isString x
      then parse x
      else x.pname or (parse x.name);

  sources = import ./sources.nix;
in

{ pkgs ? dappPkgs, system ? currentSystem }: rec {
  nodepkgs = let
    nodepkgs' = import ./nodepkgs.nix { inherit pkgs system; };
    shortNames = listToAttrs (map
      (x: { name = removePrefix "node_" (getName x.name); value = x; })
      (attrValues nodepkgs')
    );
  in nodepkgs' // shortNames;

  ssb-server = nodepkgs.ssb-server.override {
    buildInputs = with pkgs; [ gnumake nodepkgs.node-gyp-build ];
  };

  setzer-mcd = pkgs.callPackage sources.setzer-mcd {};

  omnia = pkgs.callPackage ../omnia { inherit ssb-server setzer-mcd; };
}
