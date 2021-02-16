{ }:

let
  sources = import ../nix/sources.nix;
  mach-nix = import sources.mach-nix {};
in

mach-nix.buildPythonPackage {
  pname = "stark-cli";
  version = "0.0.0";

  src = ./.;

  requirements = ''
    mpmath
    sympy
    ecdsa==0.16.0
  '';
}
