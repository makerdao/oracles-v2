{ oracle-suite ? (import ../nix/srcs.nix).oracle-suite }:
{ pkgs, config, lib, ... }:
let defaultFeedConfig = lib.importJSON ../omnia/config/feed.conf;
in {
  options.services.omnia = import ./omnia-options.nix { inherit lib pkgs; };
  imports = [ (import ./omnia.nix { inherit oracle-suite; }) ];
}
