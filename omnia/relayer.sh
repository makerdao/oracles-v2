#!/usr/bin/env bash

#pulls latest price of an asset from each feed
pullLatestPricesOfAssetPair () {
    local _assetPair="$1"
    #scrape all feeds
    verbose "Pulling $_assetPair Messages"
    for feed in "${feeds[@]}"; do
        verbose "Working with feed: $feed"
        #grab latest price msg of asset from feed
        priceEntry=$(pullLatestFeedMsgOfType "$feed" "$_assetPair")

        #DEBUG
        verbose "$_assetPair price msg from feed ($feed) = $priceEntry"
        [ -n "${priceEntry}" ] && ( verbose "price msg contains data" || error "Error: price msg is empty, skipping..." )
        [ "$(isAssetPair "$_assetPair" "$priceEntry")" == "true" ] && ( verbose "message is of type $_assetPair" || error "Error: Could not find recent message of type $_assetPair, skipping..." )
        [ "$(isMsgExpired "$priceEntry")" == "true" ] && ( verbose "msg timestamp is expired, skipping..." || verbose "msg timestamp is valid" ) 
        [ "$(isMsgNew "$_assetPair" "$priceEntry")" == "true" ] && ( verbose "msg timestamp is newer than last Oracle update" || verbose "Message is older than last Oracle update, skipping...")

        #verify price msg is valid and not expired
        if [ -n "${priceEntry}" ] && [ "$(isMsgExpired "$priceEntry")" == "false" ] && [ "$(isAssetPair "$_assetPair" "$priceEntry")" == "true" ] && [ "$(isMsgNew "$_assetPair" "$priceEntry")" == "true" ]; then
            verbose "Adding message from $feed to catalogue"
            entries+=( "$priceEntry" )

            #DEBUG
            verbose "Current price catalogue = ${entries[*]}"
        fi
    done
}

#consider renaming to pushNewOraclePrice
updateOracle () {
    for assetPair in "${assetPairs[@]}"; do
        local entries=()
        local _prices
        local _median
        local _sortedEntries=()

        pullLatestPricesOfAssetPair "$assetPair"

        #DEBUG
        echo "number of elements in entries = ${#entries[@]}"
        for entry in "${entries[@]}"; do
            echo entry: "$entry"
        done

        [ "$(isQuorum "$assetPair" "${#entries[@]}")" == "false" ] && continue
        _prices=$(extractPrices "${entries[@]}")
        
        #DEBUG
        echo "Prices = ${_prices[*]}"

        _median=$(getMedian "${_prices[@]}")
        log "median = $_median"

        #DEBUG
        [[ -n "$_median" && "$_median" =~ ^[+-]?[0-9]+\.?[0-9]*$ ]] && verbose "Median is valid" || error "median is invalid"
        [[ "$(isOracleStale "$assetPair" "$_median")" == "true" ]] && verbose "oracle price is stale" || verbose "oracle price is fresh"
        [[ "$(isOracleExpired "$assetPair" )" == "true" ]] && verbose "Oracle price is expired" || verbose "Oracle price is recent"

        if [[ -n "$_median" && "$_median" =~ ^[+-]?[0-9]+\.?[0-9]*$  && ( "$(isOracleStale "$assetPair" "$_median")" == "true" || "$(isOracleExpired "$assetPair")" == "true" ) ]]; then
            local allPrices=()
            local allTimes=()
            local allR=()
            local allS=()
            local allV=()
            sortMsgs "${entries[@]}"
            verbose "number of sortedEntries is ${#_sortedEntries[@]}"
            verbose "sorted messages = ${_sortedEntries[*]}"
            generateCalldata "${_sortedEntries[@]}"
            pushTransaction "$assetPair"
        fi
    done
}

sortMsgs () {
    local _msgs=( "$@" )
    verbose "Sorting Messages..."
    verbose "Presorted Messages = ${_msgs[*]}"
    readarray -t _sortedEntries < <(echo "${_msgs[*]}" | jq -s '.' | jq 'sort_by(.price)' | jq -c '.[]')
}

generateCalldata () {
    local _msgs=( "$@" )
    local _sig
    local _v
    verbose "Generating Calldata..."
    for msg in "${_msgs[@]}"; do
        _sig=$( echo "$msg" | jq -r '.signature' )
        _v=${_sig:128:2}
        allR+=( "${_sig:0:64}" )
        allS+=( "${_sig:64:64}" )
        allV+=( "$(seth --to-word "0x$_v" )" )
        allPrices+=( "$( echo "$msg" | jq -r '.price0x' )" )
        allTimes+=( "$( echo "$msg" | jq -r '.time0x' )" )
    done
    #DEBUG
    verbose "allPrices = ${allPrices[*]}"
    verbose "allTimes = ${allTimes[*]}"
    verbose "allR = ${allR[*]}"
    verbose "allS = ${allS[*]}"
    verbose "allV = ${allV[*]}"
}

pushTransaction () {
    local _assetPair="$1"
    local _oracleContract
    #TODO - calculate and use custom gas price
    _oracleContract=$(lookupOracleContract "$_assetPair")
    verbose "Sending tx..."
    tx=$(seth send --async "$_oracleContract" 'poke(uint256[],uint256[],uint8[],bytes32[],bytes32[])' \
        "[$(join "${allPrices[@]}")]" \
        "[$(join "${allTimes[@]}")]" \
        "[$(join "${allV[@]}")]" \
        "[$(join "${allR[@]}")]" \
        "[$(join "${allS[@]}")]")
    echo "TX: $tx"
    echo SUCCESS: "$(seth receipt "$tx" status)"
    echo GAS USED: "$(seth receipt "$tx" gasUsed)"
}