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
        [ "$(isMsgExpired "$priceEntry")" == "true" ] && ( error "Error: price timestamp is expired, skipping..." || verbose "price timestamp is valid" ) 
        [ "$(isAssetPair "$_assetPair" "$priceEntry")" == "true" ] && ( verbose "message is of type $_assetPair" || error "Error: Could not find recent message of type $_assetPair, skipping..." )

        #verify price msg is valid and not expired
        if [ -n "${priceEntry}" ] && [ "$(isMsgExpired "$priceEntry")" == "false" ] && [ "$(isAssetPair "$_assetPair" "$priceEntry")" == "true" ]; then
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
    verbose "Generating Calldata..."
    for msg in "${_msgs[@]}"; do
        allPrices+=( "0x$( echo "$msg" | jq -r '.price0x' )" )
        allTimes+=( "0x$( echo "$msg" | jq -r '.time0x' )" )
        sig=$( echo "$msg" | jq -r '.signature' )
        allR+=( "${sig:0:64}" )
        allS+=( "${sig:64:64}" )
        allV+=( "${sig:128:2}" )
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

# NEED TO ADD ASSETPAIR AS ARG TO GET HASHED BEFORE SIGNING SIG.
# THEN EITHER PASS THIS IN TO ORACLE EVERY TIME, BUT BETTER IS IF ORACLE CONTRACT
# HAS THIS SET IN CONSTRUCTOR. THIS ALSO MEANS YOU NEED TO CHANGE MESSAGE TYPE TO BE
# ETHUSD NOT ETH, MKRUSD NOT MKR, etc. BUT that means we cant pass that value into setzer
# since it uses "eth" not "ethusd". Think this through a bit more.
