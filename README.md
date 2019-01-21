# oracles-v2

Oracle client written in bash that utilizes secure scuttlebutt for offline message passing along with signed price data to validate identity and authenticity on-chain.

Goals of this new architecture are:
  1. Scalability
  2. Reduce costs by minimizing number of ethereum transactions and operations performed on-chain.
  3. Increase reliability during periods of network congestion
  4. Reduce latency to react to price changes
  5. Make it easy to on-board price feeds for new collateral types
  6. Make it easy to on-board new Oracles
  
Currently two main modules:

[broadcaster]
Each feed runs a broadcaster which pulls prices through Setzer, signs them with an ethereum private key, and broadcasts them as a message to the secure scuttlebutt network.

[relayer]
The relayer monitors the gossiped messages, checks for liveness, and homogenizes the pricing data and signatures into a single ethereum transaction.

[Live Kovan Oracles]     
      ETHUSD = 0x9Fe0D478D0E290d50EF8DFc08760C4ad9D2C7AE9    
      BTCUSD = 0x51322A569233db3506892881eE7710f511db96A1     
      MKRUSD = 0x55ea960cf38f9dd50591bd618ffbe55474419001     
      REPUSD = 0x89Ed12730F870a94a37E2D4004706D50456E11b2     
      DGXUSD = 0xa541D04193bCCF9c3B62ef34ebc3AA19d00BB69F     
      POLYUSD = 0x5BEBd4d264A33370046EC77b614926d44189Dcfd     

Instructions for querying Oracle price:

	     seth --to-dec $(seth call <ORACLE_CONTRACT> "read()(bytes32)")     
	 
Instructions for querying Oracle if token has standard 18 decimals:
	     
	     seth --from-wei $(seth --to-dec $(seth call <ORACLE_CONTRACT> "read()(bytes32)"))
