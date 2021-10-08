#!/usr/bin/env bash

updateNodePackages() {
	(cd "$ROOT_DIR"/nix && {
		 node2nix -i node-packages.json -c nodepkgs.nix --nodejs-10
	})
}
echo '  * updateNodePackages'