#!/bin/bash

git tag -d "${@:?"Usage: ${0##*/} TAG..."}" &&
  git push origin$(printf ' :refs/tags/%s' "$@") &&
  git push --tags
