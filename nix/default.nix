let
  inherit (builtins) map listToAttrs attrValues isString;

  sources = import ./sources.nix;

  inherit (import sources.nixpkgs {
    overlays = [ (self: super: { inherit (import "${sources.dapptools}/overlay.nix" self super) hevm; }) ];
  })
    pkgs;
  inherit (pkgs.lib.strings) removePrefix;

  getName = x: let parse = drv: (builtins.parseDrvName drv).name; in if isString x then parse x else x.pname or (parse x.name);

  ssb-patches = ../ssb-server;
in rec {
  inherit pkgs;

  makerpkgs = import sources.makerpkgs { };

  nodepkgs = let
    nodepkgs' = import ./nodepkgs.nix { pkgs = pkgs // { stdenv = pkgs.stdenv // { lib = pkgs.lib; }; }; };
    shortNames = listToAttrs (map (x: {
      name = removePrefix "node_" (getName x.name);
      value = x;
    }) (attrValues nodepkgs'));
  in nodepkgs' // shortNames;

  ssb-server = nodepkgs.ssb-server.override {
    name = "patched-ssb-server";
    buildInputs = with pkgs; [ gnumake nodepkgs.node-gyp-build git ];
    postInstall = ''
      git apply ${ssb-patches}/ssb-db+19.2.0.patch
    '';
  };

  oracle-suite = pkgs.callPackage sources.oracle-suite { };

  setzer-mcd = pkgs.callPackage sources.setzer-mcd { };

  stark-cli = pkgs.callPackage ../starkware { };

  omnia = pkgs.callPackage sources.omnia rec {
    inherit ssb-server setzer-mcd stark-cli oracle-suite;
    ethsign = pkgs.callPackage (import "${sources.dapptools}/src/ethsign") { };
    seth = pkgs.callPackage (import "${sources.dapptools}/src/seth") {
      inherit ethsign;
      dapptoolsSrc = pkgs.callPackage (import "${sources.dapptools}/nix/dapptools-src.nix") { };
    };
  };

  install-omnia = pkgs.callPackage ../systemd { inherit omnia ssb-server oracle-suite; };
}
