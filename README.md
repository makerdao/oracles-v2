# oracles-v2

This is an extremely rough (cannot emphasize this enough) prototype of the general flow for Oracles V2.0.

[broadcaster]
Each feed runs a broadcaster which pulls prices through Setzer and broadcasts them as a message to the secure scuttlebot network.

[ingester]
The ingester monitors the gossiped messages, checks for liveness, and homogenizes the pricing information into a single price.