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

  VERSION_FILE = toString ./omnia/version;
  ROOT_DIR = toString ./.;

  shellHook = ''
    updateNodePackages() {
      (cd "$ROOT_DIR"/nix && {
         node2nix -i node-packages.json -c nodepkgs.nix --nodejs-10
      } )
    }

    version() {
      cat $VERSION_FILE
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

        git commit -m "Bump >$1< version to $version" "$VERSION_FILE"
        git tag v$version-rc && {
          echo >&2 "To publish this commit as a release candidate run:"
          echo "git push --atomic origin master master:release/''${version%.0} v$version-rc"
          echo >&2
          echo >&2 "To patch this $1 release checkout the release branch:"
          echo "git checkout release/''${version%.0}"
        }
      else
        [[ $branch =~ ^release/ ]] || {
          echo >&2 "Not on a release branch, checkout a 'release/*' or create one: release minor or release major"
          return 1
        }
        if [[ -n $1 ]]; then
          local version=$(semver -i "$1" --preid rc $oldVersion)
          echo $version > "$VERSION_FILE"

          git commit -m "Bump >$1< version to $version" "$VERSION_FILE"
          git tag v$version && {
            echo >&2 "To publish this commit as a release candidate run:"
            echo "git push --atomic origin $branch v$version"
          }
        else
          [[ $oldVersion =~ -rc\. ]] || {
            echo >&2 "Current version ($oldVersion) not a Release Candidate. Run: release premajor|preminor|prepatch|prerelease"
            return 1
          }
          local version=$(semver -i $oldVersion)
          echo $version > "$VERSION_FILE"

          git commit -m "Release $version as stable" "$VERSION_FILE"
          git tag v$version && {
            git tag -f stable
            echo >&2 "To publish this commit as a stable release run:"
            echo "git push -f origin stable"
          }
        fi
      fi
    }
    echo 'Locally available commands:
      * updateNodePackages
      * version
         see current release version
      * release [--help] [LEVEL]
         - LEVEL: major, minor, patch, premajor, preminor, prepatch, or prerelease'
  '';
}
