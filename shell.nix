{ pkgsSrc ? (import ./nix/pkgs.nix {}).pkgsSrc
, pkgs ? (import ./nix/pkgs.nix { inherit pkgsSrc; }).pkgs
, ssb-caps ? null
}@args: with pkgs; let
  inherit (import ./. args) omnia ssb-server;
in pkgs.mkShell rec {
  name = "oracle-shell";
  buildInputs = omnia.runtimeDeps ++ [ nodePackages.node2nix ];

  ROOT_DIR = toString ./.;
  shellHook = ''
    updateNodePackages() {
      (cd "$ROOT_DIR"/nix && {
         node2nix -i node-packages.json -c nodepkgs.nix --nodejs-10
      } )
    }
  '';
}
