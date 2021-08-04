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

[Relay]
Relays monitor the gossiped messages, check for liveness, and homogenize the pricing data and signatures into a single ethereum transaction.

## [Live Kovan Oracles]
      BATUSD = 0xAb7366b12C982ca2DE162F35571b4d21E38a16FB
      BTCUSD = 0xf8A9Faa25186B14EbF02e7Cd16e39152b85aEEcd
      ETHBTC = 0x0E30F0FC91FDbc4594b1e2E5d64E6F1f94cAB23D
      ETHUSD = 0x0E30F0FC91FDbc4594b1e2E5d64E6F1f94cAB23D
      KNCUSD = 0x4C511ae3FFD63c0DE35D4A138Ff2b584FF450466
      ZRXUSD = 0x1A6b4f516d61c73f568ff0Da15891e670eBc1afb

## [Live Mainnet Oracles]
      BATUSD = 0x18B4633D6E39870f398597f3c1bA8c4A41294966
      BTCUSD = 0xe0F30cb149fAADC7247E953746Be9BbBB6B5751f
      ETHBTC = 0x81A679f98b63B3dDf2F17CB5619f4d6775b3c5ED
      ETHUSD = 0x64DE91F5A373Cd4c28de3600cB34C7C6cE410C85
      KNCUSD = 0x83076a2F42dc1925537165045c9FDe9A4B71AD97
      ZRXUSD = 0x956ecD6a9A9A0d84e8eB4e6BaaC09329E202E55e

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

Then run the following to make the `omnia`, `ssb-server` and `install-omnia`
commands available in your user environment:

```
nix-env -i -f https://github.com/makerdao/oracles-v2/tarball/stable
```

Get the Scuttlebot private network keys (caps) from an admin and put it in a file
(e.g. called `secret-ssb-caps.json`). The file should have the JSON format:
`{ "shs": "<BASE64>", "sign": "<BASE64>" }`.

You can use the `install-omnia` command to install Omnia as a `systemd`
service, update your `/etc/omnia.conf`, `~/.ssb/config` and migrate a
Scuttlebot secret and gossip log.


To install and configure Omnia as a feed running with `systemd`:

```
install-omnia feed \
  --from         <ETHEREUM_ADDRESS> \
  --keystore     <KEYSTORE_PATH> \
  --password     <PASS_FILE_PATH> \
  --ssb-caps     <CAPS_JSON_PATH> \
  --ssb-external <PUBLICLY_REACHABLE_IP>
```

For more information about the install CLI:

```
install-omnia help
```

The installed Scuttlebot config can be found in `~/.ssb.config`, more details
about the [Scuttlebot config](https://github.com/ssbc/ssb-config#configuration).

## Relayer Gas Price configuration

Adding a new configuration parameter to `ethereum` relayer config section: `gasPrice`.
It consist of 3 available options: 

`source` - source of gas price. **Default value: node**
Available values are: 

 - `node` - Getting Gas Price from node (using `seth gas-price`).
 - `gasnow` - Uses [GasNow](https://www.gasnow.org) API for fetching gas price.
 - `ethgasstation` - Uses [ethgasstation](https://ethgasstation.info) API for fetching Gas Price.

`multiplier` - A number the gas pice will be multiplied by after fetching. **Default value: 1**

`priority` - Gas Price priority for `gasnow` or `ethgasstation` sources. **Default value: fast**
Due to this API's return set of different prices based on required tx speed we also give you an ability to choose.
**NOTE:** this option does not have any effect if `source` is set to `node` !

Available values:

 - `slow`
 - `standard`
 - `fast`
 - `fastest`

**Example configuration:**

```json
{
  "mode": "relayer",
  "ethereum": {
    "from": "0x",
    "keystore": "",
    "password": "",
    "network": "kovan",
    "gasPrice": {
			"source": "node",
      "multiplier": 1,
      "priority": "fast"
		}
  },
  "transports":["transport-ssb"],
  "feeds": [
    "0x01"
  ],
  ...
}
```

## Development

To build from inside this repo, clone and run:

```
nix-build
```

You can then run `omnia` from `./result/bin/omnia`.

To get a development environment with all dependencies run:

```
nix-shell
cd omnia
./omnia.sh
```

Now you can start editing the `omnia` scripts and run them directly.

### Update dependencies

To update dependencies like `setzer-mcd` use `niv` e.g.:

```
nix-shell
niv show
niv update setzer-mcd
```

To update NodeJS dependencies edit the `nix/node-packages.json` file and run:

```
nix-shell
updateNodePackages
```

### Staging and release process

To create a release candidate (rc) for staging, typically after a PR has
passed its smoke and regression tests and is merged into `master`, checkout
`master` and run:

```
nix-shell --run "release minor"
```

This should bump the version of `omnia` by Semver version level `minor`
and create a new release branch with the resulting version
(e.g. `release/1.1`) and a tag with the suffix `-rc` which indicates a
release candidate that is ready for staging.

When a release candidate has been tested in staging and is deemed stable you can
run the same command in the release branch but without the Semver version level:

```
nix-shell --run release
```

This should add a Git tag to the current commit with its current version
(without suffix) and move the `stable` tag there also.
