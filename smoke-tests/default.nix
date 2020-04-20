rec {
  srcs = (import <nixpkgs> {}).callPackage ../nix/srcs.nix {};
  pkgs = srcs.makerpkgs.pkgs;
  nodepkgs = import ../nix/nodepkgs.nix { inherit pkgs; };
}
