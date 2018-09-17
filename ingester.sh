#!/usr/bin/env bash
EXPIRYINTERVAL=600000

declare -a feeds=("@SoGPH4un5Voz98oAZIbo4hYftc4slv4A+OHXPGCFHpA=.ed25519" "@4wuvO7zjo4Cp71w1mUJBOXbRAZjtr91rt7bpfhcEDmE=.ed25519" "@aS9pDFHSTfy2CY0PsO0hIpnY1BYgcpdGL2YWXHc73lI=.ed25519" "@lplSEbzl8cEDE7HTLQ2Fk2TasjZhEXbEzGzKBFQvVvc=.ed25519") 

pullMessages () {
    #this would is used for pulling all messages from all feeds with in-bounds timestamp
    #returns an array of objects containg only relevant info
    #breaks up that array into nested subarrays by feed
    /home/nkunkel/scuttlebot/bin.js logt --type price | jq -S 'select(.value.content.time >= 1536082440) | {author: .value.author, time: .value.timestamp, price: .value.content.median, asset: .value.content.asset}' | jq -s 'group_by(.author)'
}

pullLatestFeedMsg () {
    /home/nkunkel/scuttlebot/bin.js getLatest "$1" | jq -S '{author: .value.author, time: .value.timestamp, msgID: .key, previous: .value.previous, type: .value.content.type, price: .value.content.median, asset: .value.content.asset}' 
}

pullPreviousFeedMsg () {
    #trim quotes from prev key
    prev=$(sed -e 's/^"//' -e 's/"$//' <<<"$@")
    echo "Prev msg id = $prev" >&2
    /home/nkunkel/scuttlebot/bin.js get "$prev" | jq -S '{author: .author, time: .timestamp, previous: .previous, type: .content.type, price: .content.median, asset: .content.asset}'
}

pullLatestFeedPriceMsg () {
    counter=0
    #get latest message from feed
    msg=$( pullLatestFeedMsg "$1" )
	#DEBUG
	echo "[pullLatestFeedPriceMsg] msg = $msg" >&2
    #if message does not contain a price, get the previous message until we find one that does
    while (( counter < 10 )) &&  [[ $(echo "$msg" | jq '.type != "price"') = true ]]; do
        #clear previous key
        key=""
        #get key of previous message
        key=$( echo "$msg" | jq '.previous' )
        #clear previous message
        msg=""
        #stop looking if no more messages
        [[ $key == "null" ]] && break
        #DEBUG
        echo "message is not of type 'price', querying previous message with key = $key" >&2
        #grab previous message
        msg=$( pullPreviousFeedMsg "$key" )
        #increment message counter
        counter=$(( counter + 1 ))
        #DEBUG
        echo "[pullLatestFeedPriceMsg] previous msg = $msg" >&2
    done
	echo "$msg"
}

pullLatestPrices () {
    #data structure to keep track of latest prices
    priceMsgs=()
    #iterate through all feeds
    for feed in "${feeds[@]}"; do
	   #DEBUG
	   echo "Working with feed: $feed" >&2
        #grab latest price from feed
        priceMsg=$(pullLatestFeedPriceMsg "$feed")
    	#DEBUG
    	echo "[pullLatestPrices] PriceMsg = $priceMsg" >&2
        #calculate timestamp for expired price data 
        #note that date +%N does not work on OSX or mobile - fix later
        curTime=$(date +%s%3N)
        expiryTime=$(( curTime - EXPIRYINTERVAL ))
    	#DEBUG
    	echo "current time = $curTime" >&2
    	echo "expiry time = $expiryTime" >&2
    	echo "price message = $priceMsg" >&2
    	[  -n "${priceMsg}" ] && echo "priceMsg is not empty" || echo "priceMsg is empty"
    	#[ $(echo "$priceMsg" | jq '.time') -gt "$expiryTime" ] && echo "timestamp is not expired" || echo "timestamp is expired"
    	[ $(echo "$priceMsg" | jq '.type == "price"') ] && echo "message is of type price" || echo "message is not of type price"


    	if [ -n "${priceMsg}" ] && [ $(echo "$priceMsg" | jq '.time') -gt "$expiryTime" ] && [ $(echo "$priceMsg" | jq '.type == "price"') ]; then
            #DEBUG
    		echo "Price added to catalogue" >&2
    		priceMsgs+=( "$priceMsg" )
        fi
    	#DEBUG
    	echo "Current Price Catalogue = " >&2
        printf '%s\n' "${priceMsgs[@]}"
    done
}

getMedianPrice () {
    echo "number of feeds = ${#feeds[@]}" >&2
    #calculate quorum
    quorum=$(( ${#feeds[@]} - 3 ))
    echo "quorum neeeded = $quorum" >&2
    #check if quorum
    if [ ${#priceMsgs[@]} -gt $quorum ]; then
        echo "quorum achieved - extracting prices" >&2
        prices=$( extractPrices ${priceMsgs[@]} )
        echo "${prices[@]}" >&2
        #calculate median
        tr " " "\\n" <<< "${prices[@]}" | datamash median 1
    fi
}

extractPrices () {
    for msg in "${priceMsgs[@]}"; do
        echo "msg = $msg" >&2
        echo "$msg" | jq '.price'
    done
}

relayPrice () {
    median=""
    #pull latest prices from all feeds
    pullLatestPrices
    #grab median price
    median=$(getMedianPrice)
    [ -z "${median}" ] && echo "Median is empty"
    #verify median
    if [ -n "${median}" ] && [[ $median =~ ^[+-]?[0-9]+\.?[0-9]*$  ]]; then
            #construct transaction
            #send transaction to eth network via seth
            echo "Median = $median"
    fi
}

relayPrice
