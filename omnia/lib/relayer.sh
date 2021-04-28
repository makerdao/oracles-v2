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
        if [[ -z "$_quorum" || "$_quorum" -le 0 ]]; then
          error "Error - Invalid quorum, skipping..."
          continue
        fi

        pullLatestPricesOfAssetPair "$assetPair" "$_quorum"

        for entry in "${entries[@]}"; do
            echo "entry: $(jq -c <<<"$entry")"
        done

        [ "$(isQuorum "$assetPair" "${#entries[@]}")" == "false" ] && continue
        _prices=$(extractPrices "${entries[@]}")

        _median=$(getMedian "${_prices[@]}")
        log "-> median = $_median"

        if [[ ( "$(isPriceValid "$_median")" == "true" ) \
        && ( "$(isOracleStale "$assetPair" "$_median")" == "true" \
        || "$(isOracleExpired "$assetPair")" == "true" ) ]]; then
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

#pulls latest price of an asset from each feed
pullLatestPricesOfAssetPair () {
    local _assetPair="$1"
    _assetPair="${_assetPair^^}"
    local _quorum="$2"
    local _randomizedFeeds=()

    #randomize order of feeds
    _randomizedFeeds=( $(shuf -e "${feeds[@]}") )

    log "Pulling $_assetPair Messages"
    #scrape all feeds
    for feed in "${_randomizedFeeds[@]}"; do
        #stop collecting messages once quorum has been achieved
        if [ "${#entries[@]}" -eq "$_quorum" ]; then
          log "Collected enough messages for quorum"
          break
        fi
 
        log "Polling feed: $feed"
        # Grab latest price msg of asset from feed then verify price msg is
        # valid and not expired.
        local priceEntry
        if priceEntry=$(transportPull "$feed" "$_assetPair") \
        && [ -n "$priceEntry" ] \
        && [ "$(isAssetPair "$_assetPair" "$priceEntry")" == "true" ] \
        && [ "$(isMsgExpired "$_assetPair" "$priceEntry")" == "false" ] \
        && [ "$(isMsgNew "$_assetPair" "$priceEntry")" == "true" ]
        then
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
    verbose "allPrices = ${allPrices[*]}"
    verbose "allTimes = ${allTimes[*]}"
    verbose "allR = ${allR[*]}"
    verbose "allS = ${allS[*]}"
    verbose "allV = ${allV[*]}"
}
