let
  srcs = import ../../../nix/srcs.nix;
  sources = import ../../../nix/sources.nix;
in

{ makerpkgs ? import sources.makerpkgs {}
}@args:

with makerpkgs.pkgs;

let
  inherit (lib) importJSON;
  deploy = import ./. args;
in

mkShell rec {
  name = "median-shell";
  buildInputs = [
    jq
    dapp2nix
    dapp
    deploy
  ];

  shellHook = ''
    _setenv() {
      rm -rf ~/.dapp/testnet/8545
      nohup dapp testnet </dev/null &
      trap "kill $?" EXIT
      sleep 5

      export ETH_FROM="0x$(jq -r .address ~/.dapp/testnet/8545/keystore/* | head -n1)"
      export ETH_KEYSTORE=~/.dapp/testnet/8545/keystore
      export ETH_PASSWORD=/dev/null
      export ETH_RPC_URL="http://127.0.0.1:8545"
      export ETH_GAS=7000000
    }

    _setenv
    env | grep ^ETH_
  '';
}
