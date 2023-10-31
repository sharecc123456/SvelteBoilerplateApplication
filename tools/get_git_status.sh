#!/usr/bin/env bash
VN=$(git describe --abbrev=7 HEAD 2>/dev/null)

git update-index -q --refresh 2>/dev/null

test -z "$(git diff-index --name-only HEAD -- 2>/dev/null)" || VN="$VN-dirty"

if [[ $VN == "" ]]; then
	echo -n not in git
else
	echo -n $VN
fi
