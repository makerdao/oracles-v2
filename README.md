# oracles-v2

## Summary

Oracle client written in bash that utilizes secure scuttlebutt for offline message passing along with signed price data to validate identity and authenticity on-chain.

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
      ETHUSD = 0xF0c26dBB0Fb1f19793307d4E6182697a4b0F1e8F
      BTCUSD = 0x0f09d65E705a59E675fD7d59246bCB8C9A48a55C     
      MKRUSD = 0x999D31266049E636713B9726E350D82caC3DD278
      REPUSD = 0xEfA5F53c62531Cb29b8A8E298687A422b8793D72
      DGXUSD = 0x5a77A06A3B4c54C01A946De0D2Aee9aDeDdC3DB8
      POLYUSD = 0x004978Fa622C7Bd04c798c3beD445cE3b0b66877

## [Live Mainnet Oracles]
      BTCUSD = 0x064409168198A7E9108036D072eF59F923dEDC9A


## Query Oracle Contracts

Query Oracle price (returns raw hex value)

	     seth --to-dec $(seth call <ORACLE_CONTRACT> "read()(bytes32)")     
	 
Query Oracle price (returns decimal value)
*note this only currently works for standard tokens with 18 decimal places
	     
	     seth --from-wei $(seth --to-dec $(seth call <ORACLE_CONTRACT> "read()(bytes32)"))
	    
## Installation Instructions

*Currently Maker Internal only
https://docs.google.com/document/d/1onYu0_1j3fDtInay85hie92O_-zptGkGFgI0OePI86c/edit?usp=sharing

If you run into any problems with the installation instructions please contact @Nik on chat.makerdao.com
