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
      BATUSD = 0x03cba5da6c502aa574b65735a90c68a74ffcec62
      BTCUSD = 0x064409168198A7E9108036D072eF59F923dEDC9A
      DGDUSD = 0x6e29817b2034862a12580908903da3c4373fd20d
      ETHUSD = 0x06895ea93547312da6a3285465f32e03c90865c4
      GNTUSD = 0xdb7d2557be1aaad888ba6a401adbf08f95b4511c
      OMGUSD = 0x4aa05235b3b492e6892c7de733d372d84f5308ac
      REPUSD = 0xbdd1af032a7d3ff453c27bce27a4b432e6f3621b
      ZRXUSD = 0x9f2944f631db13e98a2ec0e78c60416f5f321d03


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
