#!/usr/bin/env bash

#pulls latest price of an asset from each feed
pullLatestPricesOfAssetPair () {
    local _assetPair="$1"
    local _quorum="$2"
    local _randomizedFeeds=()

    #randomize order of feeds
    _randomizedFeeds=( $(shuf -e "${feeds[@]}") )

    verbose "Pulling $_assetPair Messages"
    #scrape all feeds
    for feed in "${_randomizedFeeds[@]}"; do
        #stop collecting messages once quorum has been achieved
        [ "${#entries[@]}" -eq "$_quorum" ] && verbose "Collected enough messages for quorum" && return
 
        verbose "Working with feed: $feed"
        #grab latest price msg of asset from feed
        priceEntry=$(pullLatestFeedMsgOfType "$feed" "$_assetPair")

        #DEBUG
        verbose "$_assetPair price msg from feed ($feed) = $priceEntry"
        [ -n "${priceEntry}" ] && ( verbose "price msg contains data" || error "Error: price msg is empty, skipping..." )
        [ "$(isAssetPair "$_assetPair" "$priceEntry")" == "true" ] && ( verbose "message is of type $_assetPair" || error "Error: Could not find recent message of type $_assetPair, skipping..." )
        [ "$(isMsgExpired "$_assetPair" "$priceEntry")" == "true" ] && ( verbose "msg timestamp is expired, skipping..." || verbose "msg timestamp is valid" ) 
        [ "$(isMsgNew "$_assetPair" "$priceEntry")" == "true" ] && ( verbose "msg timestamp is newer than last Oracle update" || verbose "Message is older than last Oracle update, skipping...")

        #verify price msg is valid and not expired
        if [ -n "${priceEntry}" ] && [ "$(isMsgExpired "$_assetPair" "$priceEntry")" == "false" ] && [ "$(isAssetPair "$_assetPair" "$priceEntry")" == "true" ] && [ "$(isMsgNew "$_assetPair" "$priceEntry")" == "true" ]; then
            verbose "Adding message from $feed to catalogue"
            entries+=( "$priceEntry" )
        fi
    done
}

#consider renaming to pushNewOraclePrice
updateOracle () {
    for assetPair in "${assetPairs[@]}"; do
        local _quorum
        local _prices
        local _median
        local entries=()
        local _sortedEntries=()

        #get quorum for asset pair
        _quorum=$(pullOracleQuorum "$assetPair")
        [[ -z "$_quorum" ]] || [[ "$_quorum" -le 0 ]] && error "Error - Invalid quorum, skipping..." && continue

        pullLatestPricesOfAssetPair "$assetPair" "$_quorum"

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
            verbose "sorted messages = ${_sortedEntries[*]}"
            generateCalldata "${_sortedEntries[@]}"
            pushOraclePrice "$assetPair"
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
        allPrices+=( "$( echo "$msg" | jq -r '.priceHex' )" )
        allTimes+=( "$( echo "$msg" | jq -r '.timeHex' )" )
    done
    #DEBUG
    verbose "allPrices = ${allPrices[*]}"
    verbose "allTimes = ${allTimes[*]}"
    verbose "allR = ${allR[*]}"
    verbose "allS = ${allS[*]}"
    verbose "allV = ${allV[*]}"
}