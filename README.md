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

[Feed]
Each Feed runs a Feed client which pulls prices through Setzer, signs them with an ethereum private key, and broadcasts them as a message to the secure scuttlebutt network.

[Relayer]
The relayer monitors the gossiped messages, checks for liveness, and homogenizes the pricing data and signatures into a single ethereum transaction.

## [Live Kovan Oracles]
      BATUSD = 0xAb7366b12C982ca2DE162F35571b4d21E38a16FB
      BTCUSD = 0xf8A9Faa25186B14EbF02e7Cd16e39152b85aEEcd
      ETHUSD = 0x0E30F0FC91FDbc4594b1e2E5d64E6F1f94cAB23D

## [Live Mainnet Oracles]
      BATUSD = 0x18B4633D6E39870f398597f3c1bA8c4A41294966
      BTCUSD = 0xe0F30cb149fAADC7247E953746Be9BbBB6B5751f
      ETHUSD = 0x64DE91F5A373Cd4c28de3600cB34C7C6cE410C85

## Query Oracle Contracts

Query Oracle price Offchain   
```
rawStorage=$(seth storage <ORACLE_CONTRACT> 0x1)
seth --from-wei $(seth --to-dec ${rawStorage:34:32})
```

Query Oracle Price Onchain

```
seth --from-wei $(seth --to-dec $(seth call <ORACLE_CONTRACT> "read()(uint256)"))
```
This will require the address you are submitting the query from to be whitelisted in the Oracle smart contract.
To get whitelisted on a Kovan Oracle please send an email to nik@makerdao.com.
To get whitelisted on a Mainnet Oracle please submit a proposal in the Oracle section of the Maker Forum forum.makerdao.com
Your proposal will need to be ratified by MKR Governance to be enacted. Details of the proposal format can be found inside the Forum.

## Installation Instructions

*Currently Maker Internal only
https://docs.google.com/document/d/1onYu0_1j3fDtInay85hie92O_-zptGkGFgI0OePI86c/edit?usp=sharing

If you run into any problems with the installation instructions please contact @Nik on chat.makerdao.com

## Install with Nix

Add Maker build cache:

```sh
nix run -f https://cachix.org/api/v1/install cachix -c cachix use maker
```

Get the Scuttlbot private network keys (caps) from an admin and put it in a file
(e.g. called `secret-ssb-caps.json`). The file should have the JSON format:
`{ "shs": "<BASE64>", "sign": "<BASE64>" }`.

Then run the following to make the `omnia`, `ssb-server` and `install-omnia`
commands available in your user environment:

```
nix-env -i -f https://github.com/makerdao/oracles-v2/tarball/stable \
  --arg ssb-caps ./secret-ssb-caps.json
```

You can use the `install-omnia` command to install Omnia as a `systemd` service,
update your `/etc/omnia.conf` and migrate a Scuttlbot secret.

```
install-omnia help
```

A one-liner for installing/updating an Omnia feed as a `systemd` service:

```
nix run -f https://github.com/makerdao/oracles-v2/tarball/stable \
  --arg ssb-caps ./secret-ssb-caps.json \
  -c install-omnia feed
```

It is also possible to set the whole Scuttlebot config by using `--arg ssb-config
ssb-config.json` instead of `ssb-caps`. Make sure you set the `caps` property in your
`ssb-config.json` instead.

More details about the [Scuttlebot config](https://github.com/ssbc/ssb-config#configuration).

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

### Staging and release process

To create a release candidate for staging, typically after a PR has passed its
smoke tests and is merged to `master`, checkout `master` and run:

```
nix-shell
release minor
```

This should bump the version of `omnia` by Semver version level `minor`
and add a Git tag with the resulting version and the suffix `-rc` which
indicates a release candidate that is ready for staging.

When a release candidate has been tested in staging and is deemed stable you can
run the same command but without the Semver version level:

```
nix-shell
release
```

This should add a Git tag to the current commit with its current version
(without suffix) and move the `stable` tag.
