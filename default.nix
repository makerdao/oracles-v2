{ pkgsSrc ? (import ./nix/pkgs.nix {}).pkgsSrc
, pkgs ? (import ./nix/pkgs.nix { inherit pkgsSrc; }).pkgs
, nodepkgs ? import ./nix/nodepkgs.nix { inherit pkgs; }

, setzer-mcdSrc ? fetchGit {
    url = "https://github.com/makerdao/setzer-mcd";
    ref = "master";
    rev = "c528da640393a3d79ef314a7f86ae363d503a240";
  }

, ssb-caps ? null
, ssb-config ? null
}: with pkgs;

let
  ssb-config' =
    if (ssb-config != null)
    then ssb-config
    else (
      if (ssb-caps != null)
      then writeText
        "ssb-config"
        (builtins.toJSON {
          connections.incoming.net = [
            { port = 8007; scope = ["public" "local"]; transform = "shs"; }
          ];
          connections.incoming.ws = [
            { port = 8988; scope = ["public" "local"]; transform = "shs"; }
          ];
          caps = lib.importJSON ssb-caps;
        })
      else null
    );

  ssb-server = nodepkgs."ssb-server-15.1.0".override {
    buildInputs = [ gnumake nodepkgs."node-gyp-build-4.1.0" ];
  };

  # Wrap `ssb-server` with an immutable config.
  ssb-server' = ssb-config:
    writeScriptBin "ssb-server" ''
      #!${bash}/bin/bash -e
      ${lib.optionalString (ssb-config' != null)
        "export ssb_config=\"${ssb-config'}\""}
      exec -a "ssb-server" "${ssb-server}/bin/ssb-server" "$@"
    '';

  setzer-mcd = callPackage setzer-mcdSrc {};
in rec {
  ssb-server = ssb-server' ssb-config;
  omnia = callPackage ./omnia { inherit ssb-server setzer-mcd; };
  install-omnia = callPackage ./systemd { inherit ssb-server omnia; };
}
