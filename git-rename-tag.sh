#!/bin/bash

old=$1
new=$2

if [ -z "$old" ] || [ -z "$new" ]; then
  echo >&2 "Usage: ${0##*/} OLD NEW

OLD  Old tag name
NEW  New tag name"
  exit 1
fi

git tag "$new" "$old" && git-delete-tag "$old"
