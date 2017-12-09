#!/bin/bash
. text-formatting 2>/dev/null

if [ -z "$1" ]; then
  echo >&2 "Searches all git branches for a file.

Usage: $text_bold${0##*/}$text_norm \
[${text_ital}ERE$text_norm] [${text_ital}egrep-options$text_norm]"
  exit 1
fi

re=$1
shift
for branch in $(git for-each-ref --format="%(refname:strip=2)" refs/heads)
do
  printf '\n%s%s:%s\n' "$text_bold" "$branch" "$text_norm"
  git ls-tree -r --name-only "$branch" | egrep -e "$re" "$@"
done
