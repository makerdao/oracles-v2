let sources = import ./sources.nix; in

{ system ? builtins.currentSystem }:

import sources.nixpkgs-dapptools {
  inherit system;
  overlays = [(import "${sources.dapptools}/overlay.nix")];
}
