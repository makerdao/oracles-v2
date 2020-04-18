let srcs = (import <nixpkgs> {}).callPackage ../nix/srcs.nix {}; in

srcs.makerpkgs.pkgs
