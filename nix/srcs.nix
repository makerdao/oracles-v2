let
  inherit (builtins) map filter listToAttrs attrValues isString currentSystem;
  inherit (import sources.nixpkgs {
    overlays = [
      (import "${sources.dapptools}/overlay.nix")
      (self: super: {
        hevm = null;
        solc = null;
      })
      (self: super: {
        seth = self.callPackage (import "${sources.dapptools}/src/seth") { };
        ethsign = self.callPackage (import "${sources.dapptools}/src/ethsign") { };
      })
    ];
  })
    pkgs;
  inherit (pkgs.lib.strings) removePrefix;

  getName = x: let parse = drv: (builtins.parseDrvName drv).name; in if isString x then parse x else x.pname or (parse x.name);

  sources = import ./sources.nix;
  ssb-patches = ../ssb-server;

in rec {
  inherit pkgs;

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

  omnia = pkgs.callPackage ../omnia { inherit ssb-server setzer-mcd stark-cli oracle-suite; };

  install-omnia = pkgs.callPackage ../systemd { inherit omnia ssb-server oracle-suite; };
}
