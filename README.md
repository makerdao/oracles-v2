# oracles-v2

## Summary

Oracle client written in bash that utilizes secure scuttlebutt for offchain message passing along with signed price data to validate identity and authenticity on-chain.

## Design Goals

Goals of this new architecture are:
  1. Scalability
  2. Reduce costs by minimizing number of ethereum transactions and operations performed on-chain.
  3. Increase reliability during periods of network congestion
  4. Reduce latency to react to price changes
  5. Make it easy to on-board price feeds for new collateral types
  6. Make it easy to on-board new Oracles
 
## Architecture
Currently two main modules:

[broadcaster]
Each feed runs a broadcaster which pulls prices through Setzer, signs them with an ethereum private key, and broadcasts them as a message to the secure scuttlebutt network.

[relayer]
The relayer monitors the gossiped messages, checks for liveness, and homogenizes the pricing data and signatures into a single ethereum transaction.

## [Live Kovan Oracles]
      BATUSD = 0xbfbc7ce472a1cda4778cd4e0c718f31089d03449
      BNBUSD = 0x138c8bDc7D368764a5f6602df83c8D58c0af718d
      BTCUSD = 0x697d49b2f7b8D50B53884F9EE64443493fdE3Faf
      DGDUSd = 0xd961f51b334ac4d4b470cc638a2db85b97492bf6
      DGXUSD = 0x2b623531Efe868d26878bD94e286B3F6636638BC
      ETHUSD = 0x61232e4719f0709064a97c180c2d8802b742ed08
      GNTUSD = 0x99144c8d95ace864a95486e0ff64b99ba5093599
      MKRUSD = 0x851ebf5f4d71e7fc1704aed691cae89bfa05d5e1
      OMGUSD = 0x15f9921118bf2f12f2728e914fba27478cda0def
      REPUSD = 0xd739c99eb2b09d7aa22cb91bf850ed08caf275be
      USDCUSD = 0xc6768fb775eE8a67C53239875DE6afC68B077E4F
      ZRXUSD = 0xccddfff846a07ed8b730241da8c36cdc077074af   

## [Live Mainnet Oracles]
      BATUSD = 0x082C9B03a7F54aEb2c64c98f76Ee3379b9Acc306
      BTCUSD = 0x064409168198A7E9108036D072eF59F923dEDC9A
      DGDUSD = 0x6A94dc9C2e4Ae3A199D148E13682B1243999681e *inactive
      ETHUSD = 0x15D786B4e2A1e05AF579107834202E37C51A6CE6
      GNTUSD = 0x34247b933a0d0c4c9ddCd379F2730217a5F564f3 *inactive
      OMGUSD = 0x0D62918a63292f38bcf516226D47002C8364619F *inactive
      REPUSD = 0x4447a29574E8Ef8253Fa26f04c724714c5E5e577
      ZRXUSD = 0xB45C64311127207643913FD83516F4a089c4e5Fc


## Query Oracle Contracts
	 
Query Oracle price   
```
rawStorage=$(seth storage <ORACLE_CONTRACT> 0x1)
seth --from-wei $(seth --to-dec ${rawStorage:34:32})
```
	    
## Installation Instructions

*Currently Maker Internal only
https://docs.google.com/document/d/1onYu0_1j3fDtInay85hie92O_-zptGkGFgI0OePI86c/edit?usp=sharing

If you run into any problems with the installation instructions please contact @Nik on chat.makerdao.com

## Install with Nix

Get the Scuttlbot private network keys (caps) from an admin and put it in a file
(e.g. called `secret-ssb-caps.json`). The file should have the JSON format:
`{ "shs": "<BASE64>", "sign": "<BASE64>" }`.

Then run the following to make the `omnia`, `ssb-server` and `install-omnia`
commands available in your user environment:

```
nix-env -i -f https://github.com/makerdao/oracles-v2/tarball/master \
  --arg ssb-caps ./secret-ssb-caps.json
```

You can use the `install-omnia` command to install Omnia as a `systemd` service,
update your `/etc/omnia.conf` and migrate a Scuttlbot secret.

```
install-omnia help
```

A one-liner for installing an Omnia feed as a `systemd` service:

```
nix run -f https://github.com/makerdao/oracles-v2/tarball/master \
  --arg ssb-caps ./secret-ssb-caps.json \
  install-omnia \
  -c install-omnia feed
```

## Development

To build from inside this repo, clone and run:

```
nix-build --arg ssb-caps ./secret-ssb-caps.json
```

You can then run `omnia` from `./result/bin/omnia`.

To get a development environment with all dependencies run:

```
nix-shell --arg ssb-caps ./secret-ssb-caps.json
cd omnia
./omnia.sh
```

Now you can start editing the `omnia` scripts and run them directly.

### Update dependencies

To update NodeJS dependencies edit the `nix/node-packages.json` file and run:

```
nix-shell
updateNodePackages
```
