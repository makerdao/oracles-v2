#!/usr/bin/env bash

#pulls latest price of an asset from each feed
pullLatestPricesOfAsset () {
    local _asset="$1"
    entries=()
    #scrape all feeds
    for feed in "${feeds[@]}"; do
        verbose "Working with feed: $feed"
        #grab latest price msg of asset from feed
        priceEntry=$(pullLatestFeedMsgOfType "$feed" "$_asset")

        #DEBUG
        verbose "price entry from feed ($feed) = $priceEntry"
        [ -n "${priceEntry}" ] && echo "priceEntry contains data" || echo "Error: priceEntry is empty"
        [ "$(isMsgExpired "$priceEntry")" == "true" ] && echo "Error: price timestamp is expired" || echo " price timestamp is valid"
        [ "$(isAsset "$_asset" "$priceEntry")" == "true" ] && echo "message is of type $_asset" || echo "Error: message is not of type $_asset"

        #verify price msg is valid and not expired
        if [ -n "${priceEntry}" ] && [ "$(isMsgExpired "$priceEntry")" == "false" ] && [ "$(isAsset "$_asset" "$priceEntry")" == "true" ]; then
            verbose "Added message from $feed to catalogue"
            entries+=( "$priceEntry" )

            #DEBUG
            verbose "Current price catalogue = "
            printf '%s\n' "${entries[@]}"
        fi
    done
}

#consider renaming to pushNewOraclePrice
updateOracle () {
    for asset in "${assets[@]}"; do
        local _prices
        local _median
        local _priceMsgs
        local _sortedPriceMsgs
        _priceMsgs=$(pullLatestPricesOfAsset "$asset")
        [ "$(isQuorum "${_priceMsgs[@]}")" == "false" ] && return
        _prices=$(extractPrices "${_priceMsgs[@]}")
        _median=$(getMedian "${_prices[@]}")
        if [[ -n "$_median" && "$_median" =~ ^[+-]?[0-9]+\.?[0-9]*$  && ( "$(isOracleStale "$_median")" == "true" || "$(isOracleExpired)" == "true" ) ]]; then
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
    seth send $
}

sortMsgs () {
    local _msgs=( "$@" )
    verbose "Sorting Messages..."
    echo "${_msgs[@]}" | jq 'select(price: .value.content.median, 0xprice: .value.content.0xmedian, time .value.content.time, 0xtime: .value.content.0xtime, signature: .value.content.signature' | jq 'sort_by(.value.content.median)'
}

#NOTES
#pushPriceData() $calldata $asset {
#    lookupFeedContract($asset) //from config
#    getGasPrice from ethgasstation api
#    seth send $contract (this should come from config file) $calldata
#    //look how setzer checks if tx completed and adjusts gas price
#}
