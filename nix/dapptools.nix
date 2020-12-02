#
# TODO: This file is only to avoid downloading Nixpkgs Git repo and should
#       be removed when dapptools is bumped to latest release.
#
let sources = import ./sources.nix; in

{ system ? builtins.currentSystem }:

import sources.nixpkgs-dapptools {
  inherit system;
  overlays = [(import "${sources.dapptools}/overlay.nix")];
}
