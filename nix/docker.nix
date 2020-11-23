let
  srcs = import ../nix/srcs.nix;

  inherit (builtins) readFile;
  inherit (srcs) pkgs ssb-server;

  omnia = srcs.omnia { gofer = import ../gofer {}; };

  path = with pkgs; lib.makeBinPath [
    coreutils bash jq gnused
    ssb-server omnia
  ];
in with pkgs;

runCommand "omnia-runner" { nativeBuildInputs = [ makeWrapper ]; } ''
  mkdir -p $out/bin
  cp ${../docker/bin}/* $out/bin
  for x in $out/bin/*; do
    wrapProgram "$x" \
      --set PATH "$out/bin:${path}"
  done
''
