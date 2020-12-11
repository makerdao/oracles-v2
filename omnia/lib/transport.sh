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
	local _feed="$1"
	local _assetPair="$2"
	local _puller
	local _msg
	local -A _msgs

	for _puller in "${OMNIA_MESSAGE_PULLERS[@]}"; do
		log "Pulling $_assetPair price message with $_puller"

		_msg=$("$_puller" pull "$_feed" "$_message" | jq -c)

		if [[ -n $_msg ]]; then
			_msgs["$_puller"]="$_msg"
		else
			error "Failed pulling $_assetPair price from feed $_feed with $_puller"
		fi
	done

	# Return the latest of the messages pulled.
	jq -se 'max_by(.time)' <<<"${_msgs[@]}"
}

