let
  srcs = import ../../../nix/srcs.nix;
  sources = import ../../../nix/sources.nix;
in

{ makerpkgs ? import sources.makerpkgs {}
, srcRoot ? null
, ...
}@args:

with makerpkgs.pkgs;

let
  inherit (builtins) mapAttrs attrValues;
  inherit (callPackage ./dapp2.nix { inherit srcRoot; }) specs packageSpecs;

  # Update dependency specs with default values
  deps = packageSpecs (mapAttrs (_: spec:
    spec // {
      #inherit doCheck;
      solc = solc-versions.solc_0_5_12;
    }
  ) specs.this.deps);
in

pkgs.makerScriptPackage {
  name = "median-deploy";

  # Specify files to add to build environment
  src = lib.sourceByRegex ./. [
    "bin" "bin/.*"
  ];

  solidityPackages = attrValues deps;
}
