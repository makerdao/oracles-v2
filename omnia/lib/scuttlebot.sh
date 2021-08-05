if command -v ssb-server; then
	# ssb-server is in PATH, do nothing
	true
else
	# ssb-server not in PATH add a shim pointing to local install in HOME
	ssb-server() {
		"$HOME"/ssb-server/bin.js "$@"
	}
fi

#get id of scuttlebot peer
getFeedId() {
	ssb-server whoami 2> /dev/null | jq -r '.id'
}
