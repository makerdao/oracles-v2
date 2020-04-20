let srcs = (import <nixpkgs> {}).callPackage ./nix/srcs.nix {}; in

{ pkgs ? srcs.makerpkgs.pkgs
, ssb-caps ? null
}@args: with pkgs; let
  inherit (import ./. args) omnia ssb-server;
in mkShell rec {
  name = "oracle-shell";
  buildInputs = omnia.runtimeDeps ++ [
    nodePackages.node2nix
    nodePackages.semver
    git
  ];

  VERSION_FILE = toString ./omnia/version;
  ROOT_DIR = toString ./.;

  shellHook = ''
    updateNodePackages() {
      (cd "$ROOT_DIR"/nix && {
         node2nix -i node-packages.json -c nodepkgs.nix --nodejs-10
      } )
    }

    release() {
      if [[ $1 ]]; then
        semver -i "$1" $(cat "$VERSION_FILE") > "$VERSION_FILE"
        git commit -m "Bump $1 version to $(cat $VERSION_FILE)" "$VERSION_FILE"
        git tag v$(cat "$VERSION_FILE")-rc && {
          echo "To publish this commit as a release candidate run:" >&2
          echo "git push && git push --tags"
        }
      else
        git tag v$(cat "$VERSION_FILE") && {
          git tag -f stable
          echo "To publish this commit as a stable release run:" >&2
          echo "git push --tags -f"
        }
      fi
    }
  '';
}
