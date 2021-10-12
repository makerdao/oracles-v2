#!/usr/bin/env bash

version() {
	local _v
	_v=$(cat "$VERSION_FILE" 2>/dev/null)
	if [[ -z $_v ]]; then
		_v="0.0.0"
	fi
	echo "$_v"
}
echo ' * version'

release() {
	local _level="${1:-stable}"
	if [[ $_level =~ -?-he?l?p? ]]; then
		echo >&2 "Usage: release [ -h | --help ] [ LEVEL [ -e | --exact ] ]"
		echo >&2 "  Arguments:"
		echo >&2 "    LEVEL: major | minor | patch | rc | stable"
		echo >&2 "  Options:"
		echo >&2 "    -e | --exact: major, minor and patch LEVEL will be prepended by 'pre' if this is not present"
		return 1
	fi
	shift
	local OPT_EXACT=""
	local OPT_FORCE=""
	while [[ -n "$1" ]]; do
		case "$1" in
			-e|--exact)
				OPT_EXACT="yes"
				;;
			-f|--force)
				OPT_FORCE="yes"
				;;
			*)
				echo >&2 "'$1' is not a valid option"
				;;
		esac
		shift
	done

	local _preId
	_preId="rc"

	if [[ $_level == "$_preId" ]]; then
		_level="prerelease"
	fi
	if [[ $_level != "stable" && ! $_level =~ ^pre && -z $OPT_EXACT ]]; then
		_level="pre$_level"
	fi

	local branch
	branch=$(git rev-parse --abbrev-ref HEAD)

	local oldVersion
	oldVersion=$(version)

	local version
	if [[ $_level =~ major|minor$ ]]; then
		[[ $branch == master || -n $OPT_FORCE ]] || {
			echo >&2 "Not on master branch, checkout 'master' to create a new release branch."
			return 1
		}

		version=$(semver --increment "$_level" --preid ${_preId} "$oldVersion")

		local _branchVersion
		_branchVersion=$(semver --increment "$version")
		_branchVersion=''${_branchVersion%.*}

		echo "$version" > "$VERSION_FILE"
		git commit -m "Start '$_branchVersion' release line with 'v$version'" "$VERSION_FILE"
		git tag "v$version" || {
			echo >&2
			echo >&2 "Failed to create tag. Use force if necessary."
			echo "   git tag v$version --force"
		}
		echo >&2
		echo >&2 "To publish this commit as a release candidate run:"
		echo "   git push --atomic origin master master:release/$_branchVersion v$version"
		echo >&2
		echo >&2 "To patch this '$_level' release checkout the release branch:"
		echo "   git checkout release/$_branchVersion"
	elif [[ $_level =~ patch|prerelease$ ]]; then
		[[ $branch =~ ^release/ || -n $OPT_FORCE ]] || {
			echo >&2 "Not on a release branch, checkout a 'release/*' or create one by: release minor|major"
			return 1
		}

		version=$(semver --increment "$_level" --preid ${_preId} "$oldVersion")

		echo "$version" > "$VERSION_FILE"
		git commit -m "Bump '$_level' version to 'v$version'" "$VERSION_FILE"
		git tag "v$version" || {
			echo >&2
			echo >&2 "Failed to create tag. Use force if necessary."
			echo "   git tag v$version --force"
		}
		echo >&2
		echo >&2 "To publish this commit as a release candidate run:"
		echo "   git push --atomic origin $branch v$version"
	elif [[ $_level == "stable" ]]; then
		[[ $branch =~ ^release/ || -n $OPT_FORCE ]] || {
			echo >&2 "Not on a release branch, checkout a 'release/*' or create one by: release minor|major"
			return 1
		}
		[[ $oldVersion =~ -${_preId}\. ]] || {
			echo >&2 "Current version ($oldVersion) is not a Release Candidate. Run: release major|minor|patch|rc"
			return 1
		}

		version=$(semver --increment "$oldVersion")

		echo "$version" > "$VERSION_FILE"
		git commit -m "Release 'v$version' as 'stable'" "$VERSION_FILE"
		git tag "v$version" && {
			git tag stable --force
			echo >&2 "To publish this commit as a stable release run:"
			echo "   git push --atomic origin $branch v$version stable"
		}
	else
		echo >&2 "Unknown release level ($_level)"
		return 1
  fi
}
echo ' * release'