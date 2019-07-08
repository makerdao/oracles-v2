#!/usr/bin/env bash

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

        for entry in "${entries[@]}"; do
            echo entry: "$entry"
        done

        [ "$(isQuorum "$assetPair" "${#entries[@]}")" == "false" ] && continue
        _prices=$(extractPrices "${entries[@]}")

        _median=$(getMedian "${_prices[@]}")
        log "-> median = $_median"

        if [[ ( "$(isPriceValid "$_median")" == "true" ) && ( "$(isOracleStale "$assetPair" "$_median")" == "true" || "$(isOracleExpired "$assetPair")" == "true" ) ]]; then
            local allPrices=()
            local allTimes=()
            local allR=()
            local allS=()
            local allV=()
            sortMsgs "${entries[@]}"
            log "sorted messages = ${_sortedEntries[*]}"
            generateCalldata "${_sortedEntries[@]}"
            pushOraclePrice "$assetPair"
        fi
    done
}

#pulls latest price of an asset from each feed
pullLatestPricesOfAssetPair () {
    local _assetPair="$1"
    local _quorum="$2"
    local _randomizedFeeds=()

    #randomize order of feeds
    _randomizedFeeds=( $(shuf -e "${feeds[@]}") )

    log "Pulling $_assetPair Messages"
    #scrape all feeds
    for feed in "${_randomizedFeeds[@]}"; do
        #stop collecting messages once quorum has been achieved
        [ "${#entries[@]}" -eq "$_quorum" ] && log "Collected enough messages for quorum" && return
 
        log "Working with feed: $feed"
        #grab latest price msg of asset from feed
        priceEntry=$(pullLatestFeedMsgOfType "$feed" "$_assetPair")

        #verify price msg is valid and not expired
        if [ -n "${priceEntry}" ] && [ "$(isAssetPair "$_assetPair" "$priceEntry")" == "true" ] && [ "$(isMsgExpired "$_assetPair" "$priceEntry")" == "false" ] && [ "$(isMsgNew "$_assetPair" "$priceEntry")" == "true" ]; then
            log "Adding message from $feed to catalogue"
            entries+=( "$priceEntry" )
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
    log "allPrices = ${allPrices[*]}"
    log "allTimes = ${allTimes[*]}"
    log "allR = ${allR[*]}"
    log "allS = ${allS[*]}"
    log "allV = ${allV[*]}"
}