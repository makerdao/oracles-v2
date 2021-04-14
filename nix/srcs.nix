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
  ssb-patches = ../ssb-server;
in

rec {
  inherit pkgs;

  makerpkgs = import sources.makerpkgs {
    dapptoolsOverrides.default = ./dapptools.nix;
  };

  nodepkgs = let
    nodepkgs' = import ./nodepkgs.nix { inherit pkgs; };
    shortNames = listToAttrs (map
      (x: { name = removePrefix "node_" (getName x.name); value = x; })
      (attrValues nodepkgs')
    );
  in nodepkgs' // shortNames;

  ssb-server = nodepkgs.ssb-server.override {
    name = "patched-ssb-server";
    buildInputs = with pkgs; [ gnumake nodepkgs.node-gyp-build git ];
    postInstall = ''
      git apply ${ssb-patches}/ssb-db+19.2.0.patch
    '';
  };

  setzer-mcd = makerpkgs.callPackage sources.setzer-mcd {};

  stark-cli = makerpkgs.callPackage ../starkware {};

  oracle-suite = pkgs.callPackage sources.oracle-suite {};

  omnia = makerpkgs.callPackage ../omnia { inherit ssb-server setzer-mcd stark-cli oracle-suite; };

  install-omnia = makerpkgs.callPackage ../systemd {
    inherit omnia ssb-server oracle-suite;
  };

}
