{ pkgsSrc ? (import ./nix/pkgs.nix {}).pkgsSrc
, pkgs ? (import ./nix/pkgs.nix { inherit pkgsSrc; }).pkgs
, nodepkgs ? import ./nix/nodepkgs.nix { inherit pkgs; }

, setzer-mcdSrc ? fetchGit {
    url = "git@github.com:makerdao/setzer-mcd";
    ref = "master";
    rev = "c528da640393a3d79ef314a7f86ae363d503a240";
  }

, ssb-caps ? null
, ssb-config ? with pkgs; writeText "ssb-config" (builtins.toJSON ({
    port = 8007;
    ws = { port = 8988; };
  } // lib.optionalAttrs (ssb-caps != null) { caps = lib.importJSON ssb-caps; }))
}: with pkgs;

let
  ssb-server = nodepkgs."ssb-server-15.1.0".override {
    buildInputs = [ gnumake nodepkgs."node-gyp-build-4.1.0" ];
  };

  # Wrap `ssb-server` with an immutable config.
  ssb-server' = ssb-config:
    writeScriptBin "ssb-server" ''
      #!${bash}/bin/bash -e
      exec -a "ssb-server" "${ssb-server}/bin/ssb-server" "$@" -- --config "${ssb-config}"
    '';

  setzer-mcd = callPackage setzer-mcdSrc {};
in rec {
  ssb-server = ssb-server' ssb-config;
  omnia = callPackage ./omnia { inherit ssb-server setzer-mcd; };
  install-omnia-service = callPackage ./systemd { inherit ssb-server omnia; };
}
