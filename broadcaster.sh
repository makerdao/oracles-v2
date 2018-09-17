#!/usr/bin/env bash

sources="bitstamp gdax gemini kraken"

#pull price from source
getPrice () {
	source=$1
	price=$(timeout 5 setzer price "$source" 2> /dev/null)
	if [[ $price =~ ^[+-]?[0-9]+\.?[0-9]*$  ]]; then
		validSources+=( "$source" )
		validPrices+=( "$price" )
	fi
}

#sign message - this is just a placeholder
signMessage () {
    echo -n $1 $2 $3 $4 $5| sha256sum
}

#publish price  to scuttlebot
broadcastPrices () {
	cmd="/home/nkunkel/scuttlebot/bin.js publish --type price --asset $1 --id $2 --time $3 --median $4"
	[[ ${#validSources[@]} != ${#validPrices[@]} ]] && exit 1
	for index in ${!validSources[*]}; do
		cmd+=" --${validSources[index]} ${validPrices[index]}"
	done
	eval $cmd
}

#get median of  a list of numbers
getMedian () {
	prices=( "$@" )
	tr " " "\\n" <<< "${prices[@]}" | datamash median 1
}

#get unix timestamp
timestamp () {
    date +"%s"
}

#pull and broadcast price
execute () {
	for x in $sources; do
		getPrice "$x"
	done
	median=$(getMedian ${validPrices[@]})
	time=$(timestamp)
	asset=ETH
	id=Nik
	broadcastPrices $asset $id $time $median ${validSources[@]} ${validPrices[@]}
}

execute
