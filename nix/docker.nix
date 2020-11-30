let
  inherit (builtins) readFile;

  srcs = import ../nix/srcs.nix {};
  sources = import ../nix/sources.nix;

  inherit (import sources.dapptools {}) pkgs;
  inherit (srcs) ssb-server omnia;

  path = with pkgs; lib.makeBinPath [
    coreutils bash jq gnused
    ssb-server omnia
  ];
in with pkgs; runCommand "omnia-runner" { nativeBuildInputs = [ makeWrapper ]; } ''
  mkdir -p $out/bin
  cp ${../docker/bin}/* $out/bin
  for x in $out/bin/*; do
    wrapProgram "$x" \
      --set PATH "$out/bin:${path}"
  done
''
