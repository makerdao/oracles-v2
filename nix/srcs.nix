let
  inherit (builtins) map filter listToAttrs attrValues isString;
  inherit (import makerpkgs' {}) pkgs;
  inherit (pkgs) fetchgit;
  inherit (pkgs.lib.strings) removePrefix;

  getName = x:
   let
     parse = drv: (builtins.parseDrvName drv).name;
   in if isString x
      then parse x
      else x.pname or (parse x.name);

  makerpkgs' = fetchGit {
    url = "https://github.com/makerdao/makerpkgs";
    rev = "d4b7fe56b38236566b3014d328be1bd9c7be7a2f";
    ref = "master";
  };
in

rec {
  makerpkgs = import makerpkgs' {
    dapptoolsOverrides = {
      current = dapptools-seth-0_8_4-pre;
    };
  };

  dapptools-seth-0_8_4-pre = fetchgit {
    url = "https://github.com/dapphub/dapptools";
    rev = "78508c6a8db2d6d3e8e09437dbe122bb5e6b2e7e";
    sha256 = "1kwlh22q8scrd7spn3x91c9vv3axgvnqx3w8n9y4hrwkgypm7ahk";
    fetchSubmodules = true;
  };

  setzer-mcd = fetchGit {
    url = "https://github.com/makerdao/setzer-mcd";
    rev = "37418393ef70d4b6bc4b9e9ae523f4be2164e14c";
    ref = "master";
  };

  nodepkgs = { pkgs ? makerpkgs.pkgs }: let
    nodepkgs' = import ./nodepkgs.nix { inherit pkgs; };
    shortNames = listToAttrs (map
      (x: { name = removePrefix "node-" (getName x.name); value = x; })
      (attrValues nodepkgs')
    );
  in nodepkgs' // shortNames;
}
