{ oracle-suite ? (import ../nix/srcs.nix).oracle-suite }:
{ pkgs, config, lib, ... }: {
  options.services.omnia = import ./omnia-options.nix { inherit lib pkgs; };
  imports = [ (import ./omnia.nix { inherit oracle-suite; }) ];
}
