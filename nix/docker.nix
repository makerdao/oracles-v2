let
  srcs = import ./default.nix;

  inherit (builtins) readFile;
  inherit (srcs) pkgs ssb-server omnia;

  path = with pkgs; lib.makeBinPath [ coreutils findutils bash jq gnused ssb-server omnia ];
in with pkgs;

runCommand "omnia-runner" { nativeBuildInputs = [ makeWrapper ]; } ''
  mkdir -p $out/bin
  cp ${../docker/bin}/* $out/bin
  for x in $out/bin/*; do
    wrapProgram "$x" \
      --set PATH "$out/bin:${path}"
  done

''
