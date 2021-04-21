{ pkgs ? import <nixpkgs> {}, keystore ? import ./keystore.nix {}, genesisKey ? "genesis", unlockKeys ? [ "genesis" ], allocKeys ? [] }:
let
  __listToBalances = list:
    let
      recurse = list: balances: n:
        if n < builtins.length list
        then recurse list (balances // builtins.listToAttrs [{ name = builtins.elemAt list n; value = { "balance" = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"; }; }]) (n+1)
        else balances;
    in recurse list {} 0;

  # Testchain configuration:
  genesisAddr = keystore.address genesisKey;
  unlockAddrs = pkgs.lib.forEach unlockKeys keystore.address;
  chainId = 99;
  dataDir = "/var/lib/testchain";
  rpcPort = 8545;
  rpcAddr = "0.0.0.0";
  genesis = pkgs.writeText "genesis.json" (builtins.toJSON {
    alloc = __listToBalances ([genesisAddr] ++ pkgs.lib.forEach allocKeys keystore.address);
    config = {
      byzantiumBlock = 0;
      chainId = chainId;
      clique = {
        epoch = 3000;
        period = 0;
      };
      constantinopleBlock = 0;
      eip150Block = 0;
      eip155Block = 0;
      eip158Block = 0;
      eip160Block = 0;
      homesteadBlock = 0;
      istanbulBlock = 0;
      petersburgBlock = 0;
    };
    difficulty = "0x1";
    extraData = "0x3132333400000000000000000000000000000000000000000000000000000000${genesisAddr}0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    gaslimit = "0xffffffffffffffff";
  });

  geth-testchain = pkgs.writeShellScript "geth-testchain" ''
    mkdir -p ${dataDir}
    if [[ "$(realpath "${dataDir}"/genesis.json)" != "${genesis}" ]]; then
      ln -sf "${genesis}" "${dataDir}/genesis.json"
      ln -sfT "${keystore.keystorePath}" "${dataDir}"/keystore

      ${pkgs.go-ethereum}/bin/geth \
        --datadir "${dataDir}" \
        init "${dataDir}/genesis.json"

      for ((n=0;n<${toString ((builtins.length unlockAddrs) + 1)};n++)); do
        cat ${keystore.passwordFile} >> ${dataDir}/passwords
      done
    fi

    ${pkgs.go-ethereum}/bin/geth \
      --datadir "${dataDir}" \
      --networkid "${toString chainId}" \
      --mine \
      --minerthreads=1 \
      --allow-insecure-unlock \
      --rpc \
      --rpcapi "web3,eth,net,debug,personal" \
      --rpccorsdomain="*" \
      --rpcvhosts="*" \
      --nodiscover \
      --rpcaddr="${rpcAddr}" \
      --rpcport="${toString rpcPort}" \
      --unlock="${builtins.concatStringsSep "," (map (x: "0x" + x) (unlockAddrs ++ [genesisAddr]))}" \
      --password="${dataDir}/passwords" \
      --etherbase="0x${genesisAddr}"
  '';
in pkgs.stdenv.mkDerivation {
  name = "geth-testchain";

  unpackPhase = "true";

  buildInputs = [
    pkgs.go-ethereum
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp ${geth-testchain} $out/bin/geth-testchain
  '';
}
