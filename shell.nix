let
  srcs = import ./nix/srcs.nix;
in

{ pkgs ? srcs.pkgs
}@args:

let oracles = import ./. args; in

pkgs.mkShell rec {
  name = "oracle-shell";
  buildInputs = oracles.omnia.runtimeDeps ++ (with pkgs; [
    git niv
    nodePackages.node2nix
    nodePackages.semver
  ]);

  VERSION_FILE = toString ./omnia/lib/version;
  ROOT_DIR = toString ./.;

  shellHook = ''
    updateNodePackages() {
      (cd "$ROOT_DIR"/nix && {
         node2nix -i node-packages.json -c nodepkgs.nix --nodejs-10
      } )
    }

    release() {
      local branch=$(git rev-parse --abbrev-ref HEAD)
      local oldVersion=$(cat $VERSION_FILE)
      if [[ $1 =~ -?-?help ]]; then
        echo >&2 "Usage: release SEMVER"
        semver --help
      elif [[ $1 =~ minor|major ]]; then
        [[ $branch == master ]] || {
          echo >&2 "Not on master branch, checkout 'master' to make a new release branch."
          return 1
        }
        local version=$(semver -i "$1" $oldVersion)
        echo $version > "$VERSION_FILE"
        git commit -m "Bump $1 version to $version" "$VERSION_FILE"
        git checkout -b release/''${version%.0}
        git tag v$version-rc && {
          echo >&2 "To publish this commit as a release candidate run:"
          echo "git push -u origin release/''${version%.0} && git push --tags"
        }
      else
        [[ $branch =~ ^release/ ]] || {
          echo >&2 "Not on a release branch, checkout a 'release/*' or create one: release minor or release major"
          return 1
        }
        if [[ -n $1 ]]; then
          local version=$(semver -i "$1" $oldVersion)
          echo $version > "$VERSION_FILE"
          git commit -m "Bump $1 version to $version" "$VERSION_FILE"
          git tag v$version-rc && {
            echo >&2 "To publish this commit as a release candidate run:"
            echo "git push && git push --tags"
          }
        else
          git tag v$oldVersion && {
            git tag -f stable
            echo >&2 "To publish this commit as a stable release run:"
            echo "git push --tags -f"
          }
        fi
      fi
    }
  '';
}
