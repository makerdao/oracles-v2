{ pkgs ? import <nixpkgs> {}}:
let
  # Address used for the genesis block
  genesisKey = "genesis";
  # List of feeders, these addresses are allowed to send pricees
  feedersKeys = ["feeder"];
  # List of relayers, these addresses will be able to connect to the RPC api
  relayerKeys = ["relayer"];
  # List of contracts to deploy
  pairs = ["BATUSD" "BTCUSD" "ETHUSD" "KNCUSD" "MANAUSD"];

  makerPkgs = import (builtins.fetchTarball "https://github.com/makerdao/makerpkgs/tarball/4d71760d27e88e244f9b5fe4d064b4c207b9b92d") { inherit pkgs; };
  keystore = import ./keystore.nix { pkgs = makerPkgs; };
  medianDeploy = import ./median-deploy.nix { pkgs = makerPkgs; };
  gethTestchain = import ./geth-testchain.nix { pkgs = makerPkgs; keystore = keystore; genesisKey = genesisKey; unlockKeys = relayerKeys; allocKeys = feedersKeys ++ relayerKeys; };

  medianDeployerBin = pkgs.writeShellScript "median-deployer" ''
    # Run go-ethereum in background
    ${gethTestchain}/bin/geth-testchain &
    pid=$!

    OUTPUT=$1
    export ETH_GAS=7000000
    export ETH_KEYSTORE=${keystore.keystorePath}
    export ETH_FROM=${keystore.address genesisKey}
    export ETH_PASSWORD=${keystore.passwordFile}

    # Deploy medianizer contracts
    ${medianDeploy}/bin/median-deploy ${builtins.concatStringsSep " " pairs} ${builtins.concatStringsSep " " (map (x: "0x" + (keystore.address x)) feedersKeys)} > $OUTPUT

    # Stop go-ethereum process
    kill "$pid"
  '';

  testchainRunnerBin = pkgs.writeShellScript "testchain-runner" ''
    ${gethTestchain}/bin/geth-testchain
  '';
in pkgs.stdenv.mkDerivation {
  name = "geth-testchain";

  unpackPhase = "true";

  buildInputs = [
    medianDeploy
    gethTestchain
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp ${medianDeployerBin} $out/bin/median-deployer
    cp ${testchainRunnerBin} $out/bin/testchain-runner
  '';
}
