let srcs = import ./nix;

in { pkgs ? srcs.pkgs }@args:

let oracles = import ./. args;

in pkgs.mkShell rec {
  name = "oracle-shell";
  buildInputs = oracles.omnia.runtimeDeps ++ (with pkgs; [ git niv nodePackages.node2nix nodePackages.semver ]);

  VERSION_FILE = toString ./version;
  ROOT_DIR = toString ./.;

  shellHook = ''
    source ${./shell/versioning.sh}
    source ${./shell/functions.sh}
  '';
}
