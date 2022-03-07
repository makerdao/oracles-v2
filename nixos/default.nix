{ oracle-suite ? (import ../nix).oracle-suite }:
{ pkgs, lib, ... }: {
  options.services.omnia = import ./omnia-options.nix { inherit lib pkgs; };
  imports = [ (import ./omnia.nix { inherit oracle-suite; }) ];
}
