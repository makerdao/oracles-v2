ssb-server() {
	local _wdir="${wdir:-$tpath}"
	case "$1" in
		publish) cat > "$_wdir/output";;
		createUserStream) cat "$tpath/ssb-create-user-stream-resp.ndjson";;
		*) return 1;;
	esac
}
export -f ssb-server

gofer() {
	case "${*^^}" in
		*BAT/USD*) cat "$tpath/gofer-batusd-resp.json";;
		*MKR/USD*) cat "$tpath/gofer-mkrusd-resp.json";;
		*) return 1;;
	esac
}
export -f gofer

setzer() {
	case "$1-$2-$3" in
		sources-batusd-) printf "a\nb\nc\n";;
		price-batusd-a) echo 0.1;;
		price-batusd-b) echo 0.2;;
		price-batusd-c) echo 0.3;;
		*) return 1;;
	esac
}
export -f setzer
