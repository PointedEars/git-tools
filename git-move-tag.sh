#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ]; then
  echo >&2 "Usage: ${0##*/} TAG TARGET"
  exit 1
fi

git pull --tags &&
  git tag -a "$1" "$2" -f &&
  git push origin --tags -f
