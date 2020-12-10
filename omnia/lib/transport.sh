transportPublish() {
	local _assetPair="$1"
	local _message="$2"
	local _succ=0
	for _publisher in "${OMNIA_FEED_PUBLISHERS[@]}"; do
		log "Publishing $_assetPair price message with $_publisher"
		if "$_publisher" publish "$_message"; then
			((_succ++))
		else
			error "Failed publishing $_assetPair price with $_publisher"
		fi
	done

	[[ $_succ -gt 0 ]]
}

transportPull() {
	local assetPair="$1"
	local puller
	for puller in "${OMNIA_MESSAGE_PULLERS[@]}"; do
		log "Pulling $assetPair price message with $puller"

		if "$puller" pull "$_message" | jq -c; then
			true
		else
			error "Failed pulling $assetPair price with $puller"
		fi
	done
}

