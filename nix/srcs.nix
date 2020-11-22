let
  inherit (builtins) map filter listToAttrs attrValues isString currentSystem;
  inherit (import sources.nixpkgs {}) pkgs;
  inherit (pkgs) fetchgit;
  inherit (pkgs.lib.strings) removePrefix;

  getName = x:
   let
     parse = drv: (builtins.parseDrvName drv).name;
   in if isString x
      then parse x
      else x.pname or (parse x.name);

  sources = import ./sources.nix;
in

rec {
  inherit pkgs;

  makerpkgs = import sources.makerpkgs {
    dapptoolsOverrides.default = ./dapptools.nix;
  };
  gofer = import ../../gofer {};

  nodepkgs = let
    nodepkgs' = import ./nodepkgs.nix { inherit pkgs; };
    shortNames = listToAttrs (map
      (x: { name = removePrefix "node_" (getName x.name); value = x; })
      (attrValues nodepkgs')
    );
  in nodepkgs' // shortNames;

  ssb-server = nodepkgs.ssb-server.override {
    buildInputs = with pkgs; [ gnumake nodepkgs.node-gyp-build ];
  };

  setzer-mcd = makerpkgs.callPackage sources.setzer-mcd {};

  stark-cli = makerpkgs.callPackage ../starkware {};

  omnia = makerpkgs.callPackage ../omnia { inherit ssb-server setzer-mcd stark-cli; };

  install-omnia = makerpkgs.callPackage ../systemd { inherit ssb-server omnia; };
}
