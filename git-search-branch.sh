#!/bin/bash
re=${1:?"Usage: ${0##*/} [ERE] [egrep-options]"}
shift
for branch in $(git for-each-ref --format="%(refname:strip=2)" refs/heads)
do
  printf '\n%s:\n\n' "$branch"
  git ls-tree -r --name-only "$branch" | egrep -e "$re" "$@"
done
