ssb-server() {
	echo "$*" >> "$tpath/log-ssb-server.txt"
	local _wdir="${wdir:-$tpath}"
	case "$1" in
		publish)
			cat > "$_wdir/output"
			cat "$_wdir/output" >> "$tpath/log-ssb-server.txt"
			;;
		createUserStream) cat "$tpath/ssb-create-user-stream-resp.ndjson";;
		*) return 1;;
	esac
}
export -f ssb-server

gofer() {
	echo "$*" >> "$tpath/log-gofer.txt"
	case "${*^^}" in
		*MKR/USD*) cat "$tpath/gofer-mkrusd-resp.json";;
		*) return 1;;
	esac
}
export -f gofer

setzer() {
	echo "$1-$2-$3" >> "$tpath/log-setzer.txt"
	case "$1-$2-$3" in
		sources-mkrusd-) printf "a\nb\nc\n";;
		price-mkrusd-a) echo 0.11;;
		price-mkrusd-b) echo 0.22;;
		price-mkrusd-c) echo 0.33;;
		*) return 1;;
	esac
}
export -f setzer
