#!/bin/bash

appname=${0##*/}
bold=$(tput bold 2>/dev/null)
ital=$(tput sitm 2>/dev/null)
norm=$(tput sgr0 2>/dev/null)

commit_hash=$1
committer_date=$2
author_date=$3

if [ -z "$commit_hash" ] || [ -z "$committer_date" ]; then
  echo "Sets the date(s) of a commit.

Usage: $bold$appname$norm ${ital}COMMIT_HASH$norm ${ital}COMMITTER_DATE$norm [${ital}AUTHOR_DATE$norm]

Rewrites the repository history so that the commit identified by
${ital}COMMIT_HASH$norm (full, 7-character short hash, or hash range)
has the committer date ${ital}COMMITTER_DATE$norm.  If ${ital}COMMITTER_DATE$norm
is \`-', the committer date will not be changed; you must specify
${ital}AUTHOR_DATE$norm then.

If ${ital}AUTHOR_DATE$norm is not provided, the authoring date will not
be changed.
If ${ital}AUTHOR_DATE$norm is \`-', it will be changed to ${ital}COMMITTER_DATE$norm.

Uncommitted changes are preserved using ${bold}git stash$norm."
  exit 1
fi

[ "$committer_date" = '-' ] && unset committer_date

if [ -n "$committer_date" ] && [ "$author_date" = '-' ]; then
  author_date=$committer_date
elif [ -z "$committer_date" ] &&
    [ -z "$author_date" ] || [ "$author_date" = '-' ]; then
  echo 'You must provide an authoring date if you do not change the committer date.' | (fold -s ${COLUMNS:+'-w $COLUMNS'} 2>/dev/null || cat) >&2
  exit 1
fi

echo "<$commit_hash>: --> ${committer_date:+"committer_date=$committer_date"}${author_date:+", author_date=$author_date"}"

git stash && (
    if echo "$commit_hash" | egrep -e '.+\.\..+' >/dev/null 2>&1; then
      start_hash=$(echo "$commit_hash" | awk -F '\\.\\.' '{print $1}')
      end_hash=$(echo "$commit_hash" | awk -F '\\.\\.' '{print $2}')
      tmpfile=$(mktemp)
      export tmpfile
    fi

    git filter-branch -f --env-filter '
      git_short_hash=${GIT_COMMIT%${GIT_COMMIT#???????}}

      if [ -n "'"$start_hash"'" ] || [ -n "'"$end_hash"'" ]; then
        if ([ -n "'"$start_hash"'" ] && [ "$GIT_COMMIT" = "'"$start_hash"'" ] ||
        [ "$git_short_hash" = "'"${start_hash%${start_hash#???????}}"'" ]) ||
        ([ -z "'"$start_hash"'" ] && [ -n "'"$end_hash"'" ]); then
          file_in_range=$(mktemp)
          echo "$file_in_range" >> "'"$tmpfile"'"
        else
          file_in_range=$(cat "'"$tmpfile"'")
        fi
      fi

      if ([ -n "$file_in_range" ] && [ -f "$file_in_range" ]) ||
      [ "$GIT_COMMIT" = "'"$commit_hash"'" ] ||
      ([ '${#commit_hash}' -eq 7 ] && [ "$git_short_hash" = "'"$commit_hash"'" ]); then
        [ -n "'"$committer_date"'" ] && export GIT_COMMITTER_DATE="'"$committer_date"'"
        [ -n "'"$author_date"'" ] && export GIT_AUTHOR_DATE="'"$author_date"'"
      fi

      if [ -n "'"$end_hash"'" ] &&
      [ "$GIT_COMMIT" = "'"$end_hash"'" ] ||
      [ "$git_short_hash" = "'"${end_hash%${end_hash#???????}}"'" ]; then
        rm "$file_in_range"
      fi
    '
    if [ -n "$start_hash" ]; then
      file_in_range="$(cat "$tmpfile")"
      [ -f "$file_in_range" ] && rm "$file_in_range"
      rm "$tmpfile"
    fi
  ) &&
    git stash pop
