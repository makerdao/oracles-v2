let
  inherit (builtins) readFile;

  srcs = import ../nix/srcs.nix {};
  sources = import ../nix/sources.nix;

  inherit (import sources.dapptools {}) pkgs;
  inherit (srcs) ssb-server omnia;

  confer = pkgs.writeShellScriptBin "confer"
    (readFile ./docker/confer);

  filer = pkgs.writeShellScriptBin "filer"
    (readFile ./docker/filer);

  runner = pkgs.writeShellScriptBin "runner"
    (readFile ./docker/runner);

  omnia-runner = with pkgs; let
    path = lib.makeBinPath [
      coreutils jq
      filer confer
      ssb-server omnia
    ];
  in runCommand "omnia-runner" { nativeBuildInputs = [ makeWrapper ]; } ''
    mkdir -p $out/bin
    makeWrapper ${runner}/bin/runner "$out/bin/omnia-runner" \
      --set PATH "${path}"
  '';
in

omnia-runner
