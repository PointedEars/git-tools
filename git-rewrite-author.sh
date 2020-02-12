#!/bin/bash

appname=${0##*/}
bold=$(tput bold 2>/dev/null)
ital=$(tput sitm 2>/dev/null)
norm=$(tput sgr0 2>/dev/null)

old_email=$1
new_email=$2
new_name=$3
shift 3

if [ -z "$old_email" ] || [ -z "$new_email" ]; then
  echo "Rewrites the author/committer of all commits in a branch.

Usage: $bold$appname$norm ${ital}OLD_EMAIL$norm ${ital}NEW_EMAIL$norm [${ital}NEW_NAME$norm [${ital}BRANCHES$norm...]]

Rewrites the history of the current branch so that commits made
by the author/committer with ${ital}OLD_EMAIL$norm are attributed to
${ital}NEW_NAME$norm <${ital}NEW_EMAIL$norm>.

If ${ital}NEW_NAME$norm is not provided or \`-', only the e-mail address will be changed.

If ${ital}BRANCHES$norm is not provided, only the commits in the current branch are affected.
Use \`--all' to modify all commits in all branches.

Uncommitted changes are preserved using ${bold}git stash$norm."
  exit 1
fi

if [ -n "$new_name" ] && [ "$new_name" = '-' ]; then
  unset new_name
fi

echo "<$old_email> --> ${new_name:+\"$new_name\" }<$new_email>"

git stash &&
  git filter-branch --env-filter '
    if [ "$GIT_COMMITTER_EMAIL" = "'"$old_email"'" ]
    then
      [ -n "'"$new_name"'" ] && export GIT_COMMITTER_NAME="'"$new_name"'"
      export GIT_COMMITTER_EMAIL="'"$new_email"'"
    fi
    if [ "$GIT_AUTHOR_EMAIL" = "'"$old_email"'" ]
    then
      [ -n "'"$new_name"'" ] && export GIT_AUTHOR_NAME="'"$new_name"'"
      export GIT_AUTHOR_EMAIL="'"$new_email"'"
    fi
    ' --tag-name-filter cat -f -- --branches --tags "$@" &&
  git stash pop
