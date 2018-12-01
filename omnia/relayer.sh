#!/usr/bin/env bash

#pulls latest price of an asset from each feed
pullLatestPricesOfAsset () {
    local _asset="$1"
    #scrape all feeds
    verbose "Pulling $_asset Messages"
    for feed in "${feeds[@]}"; do
        verbose "Working with feed: $feed"
        #grab latest price msg of asset from feed
        priceEntry=$(pullLatestFeedMsgOfType "$feed" "$_asset")

        #DEBUG
        verbose "$_asset price msg from feed ($feed) = $priceEntry"
        [ -n "${priceEntry}" ] && ( verbose "price msg contains data" || error "Error: price msg is empty, skipping..." )
        [ "$(isMsgExpired "$priceEntry")" == "true" ] && ( error "Error: price timestamp is expired, skipping..." || verbose "price timestamp is valid" ) 
        [ "$(isAsset "$_asset" "$priceEntry")" == "true" ] && ( verbose "message is of type $_asset" || error "Error: Could not find recent message of type $_asset, skipping..." )

        #verify price msg is valid and not expired
        if [ -n "${priceEntry}" ] && [ "$(isMsgExpired "$priceEntry")" == "false" ] && [ "$(isAsset "$_asset" "$priceEntry")" == "true" ]; then
            verbose "Adding message from $feed to catalogue"
            entries+=( "$priceEntry" )

            #DEBUG
            verbose "Current price catalogue = ${entries[*]}"
        fi
    done
}

#consider renaming to pushNewOraclePrice
updateOracle () {
    for asset in "${assets[@]}"; do
        local entries=()
        local _prices
        local _median
        local _sortedPriceMsgs
        pullLatestPricesOfAsset "$asset"

        #DEBUG
        echo "number of elements in entries = ${#entries[@]}"
        for entry in "${entries[@]}"; do
            echo entry: "$entry"
        done

        [ "$(isQuorum "$asset" "${#entries[@]}")" == "false" ] && log "Not enough feeds (${#entries[@]}) to reach quorum" && continue
        _prices=$(extractPrices "${entries[@]}")
        #DEBUG
        echo "Prices = ${_prices[*]}"

        _median=$(getMedian "${_prices[@]}")
        log "median = $_median"

        #DEBUG
        [[ -n "$_median" && "$_median" =~ ^[+-]?[0-9]+\.?[0-9]*$ ]] && verbose "Median is valid" || error "median is invalid"
        [[ "$(isOracleStale "$asset" "$_median")" == "true" ]] && verbose "oracle price is stale" || verbose "oracle price is fresh"
        [[ "$(isOracleExpired "$asset" )" == "true" ]] && verbose "Oracle price is expired" || verbose "Oracle price is recent"

        if [[ -n "$_median" && "$_median" =~ ^[+-]?[0-9]+\.?[0-9]*$  && ( "$(isOracleStale "$asset" "$_median")" == "true" || "$(isOracleExpired "$asset")" == "true" ) ]]; then
            local allPrices=()
            local allT=()
            local allR=()
            local allS=()
            local allV=()
            _sortedPriceMsgs=$(sortMsgs "${_priceMsgs[@]}")
            generateCalldata "${_sortedPriceMsgs[@]}"
            pushNewOraclePrice
        fi
    done
}

sortMsgs () {
    local _msgs=( "$@" )
    verbose "Sorting Messages..."
    echo "${_msgs[@]}" | jq 'select(price: .value.content.median, 0xprice: .value.content.0xmedian, time .value.content.time, 0xtime: .value.content.0xtime, signature: .value.content.signature' | jq 'sort_by(.value.content.median)'
}

generateCalldata () {
    local _msgs=( "$@" )
    verbose "Generating Calldata..."
    for msg in "${_msgs[@]}"; do
        allPrices+=("$("0x" + "$(echo "$msg" | jq '.0xprice')")")
        allT+=("$('0x' + "$(echo "$msg" | jq '.0xtime')")")
        allR+=("$('0x' + "${"$(echo "$msg" | jq '.signature')":0:64})")")
        allS+=("$('0x' + "${"$(echo "$msg" | jq '.signature')":64:64}")")
        allV+=("$('0x' + "${"$(echo "$msg" | jq '.signature')":128:2}")")
    done
}

pushNewOraclePrice () {
    #get gas price from eth gas station
    
    verbose "Sending tx..."
    #seth send $
}

#NOTES
#pushPriceData() $calldata $asset {
#    lookupFeedContract($asset) //from config
#    getGasPrice from ethgasstation api
#    seth send $contract (this should come from config file) $calldata
#    //look how setzer checks if tx completed and adjusts gas price
#}
