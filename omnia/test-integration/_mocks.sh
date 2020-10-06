ssb-server() {
	case "$1" in
		publish) cat > "$wdir/output";;
		createUserStream) cat "$tpath/ssb-create-user-stream-resp.json";;
		*) return 1;;
	esac
}
export -f ssb-server

rpath="$tpath/../../smoke-tests/resources"
ETH_FROM="0x1f8fbe73820765677e68eb6e933dcb3c94c9b708"
ETH_KEYSTORE="$rpath/keys"
ETH_PASSWORD="$rpath/key"
