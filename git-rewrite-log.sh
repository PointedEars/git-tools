#!/bin/bash

appname=${0##*/}
bold=$(tput bold 2>/dev/null)
undl=$(tput smul 2>/dev/null)
norm=$(tput sgr0 2>/dev/null)

_help ()
{
  echo "Rewrites the repository history.

Usage: $bold$appname$norm
  [-E ${undl}OLD_EMAIL$norm] [-e ${undl}NEW_EMAIL$norm || -n ${undl}NEW_NAME$norm]
  [-H ${undl}COMMIT_HASH$norm [-d ${undl}COMMITTER_DATE$norm || -a ${undl}AUTHOR_DATE$norm]] [--] [${undl}BRANCHES$norm...]

${bold}OPTIONS$norm

  Search parameters:

    ${bold}-E$norm, ${bold}--old-email$norm=${undl}OLD_COMMITTER_EMAIL$norm
    ${bold}-H$norm, ${bold}--hash$norm=${undl}COMMIT_HASH$norm

  New values:

    ${bold}-a$norm, ${bold}--author-date$norm=${undl}NEW_AUTHOR_DATE$norm
    ${bold}-d$norm, ${bold}--date$norm=${undl}NEW_COMMITTER_DATE$norm
    ${bold}-e$norm, ${bold}--email$norm=${undl}NEW_EMAIL$norm
    ${bold}-n$norm, ${bold}--name$norm=${undl}NEW_NAME$norm

${bold}PARAMETERS$norm

  ${undl}BRANCHES$norm    Branches to consider.  (Ignored for ${bold}-H$norm.)
              Omitting this parameter rewrites only the current branch.
              Specify \`--all' preceded by \`--' to rewrite all branches.

Uncommitted changes are preserved using ${bold}git stash$norm."
  exit ${1:-0}
}

. getopt-wrapper 2>/dev/null
if  [ $? -eq 0 ]; then
  params=$(getopt_wrapper hE:e:n:H:d:a: help,old-email,email,name,hash,date,author-date '' "$@")
  if [ $? -ne 0 ]; then echo; _help 1; fi
  [ -n "$params" ] && eval set -- "$params"
else
  printf >&2 '%s: POSIX-compliant argument parsing not available.' "$appname"
fi

while [ $# -gt 0 ]
do
  case $1 in
    -*)
      option=$1
      shift
      case $option in
        -h | --help)       _help;;
        -E | --old-email)  old_email=$1; shift;;
        -e | --email)      new_email=$1; shift;;
        -n | --name)       new_name=$1; shift;;
        -H | --hash)
          commit_hash=$1;
          if ! printf '%s' "$commit_hash" |
            egrep '^[[:space:]]*[0-9A-Fa-f]+[[:space:]]*$'; then
            printf '%s: "%s" does not look like a valid hash.  Aborting.\n\n' "$appname" "$commit_hash"
            _help 1
          fi
          shift;;
        -d | --date)       committer_date=$1; shift;;
        -a | --authordate) author_date=$1; shift;;
        --) break;;
        *) _help 1
      esac;;
    *) break
  esac
done

[ -z "$commit_hash$old_email" ] ||
  [ -z "$committer_date$author_date$new_email$new_name" ] && _help 1

if [ -n "$committer_date" ] || [ -n "$author_date" ]; then
  if [ -n "$old_email" ] && [ -z "$commit_hash" ]; then
    printf >&2 '%s: Cowardly refusing stupid dating of several commits.  RTFM.\n\n' "$appname"
    _help 1
  else
    printf >&2 '%s: New date(s) will only be set for the specified hash.\n\n' "$appname"
  fi
fi

git stash &&
  git filter-branch -f --env-filter '
    if [ -n "'"$commit_hash"'" ] && [ "$GIT_COMMIT" = "'"$commit_hash"'" ]; then
      [ -n "'"$committer_date"'" ] && export GIT_COMMITTER_DATE="'"$committer_date"'"
      [ -n "'"$author_date"'" ] && export GIT_AUTHOR_DATE="'"$author_date"'"
    fi

    if [ -n "'"$commit_hash"'" ] || [ -n "'"$old_email"'" ]; then
      if [ -n "'"$old_email"'" ] ||
          [ -n "'"$commit_hash"'" ] && [ "$GIT_COMMIT" = "'"$commit_hash"'" ]; then
        if [ -n "'"$new_email"'" ]; then
          if [ "$GIT_COMMITTER_EMAIL" = "'"$old_email"'" ]; then
            [ -n "'"$new_email"'" ] && export GIT_COMMITTER_EMAIL="'"$new_email"'"
            [ -n "'"$new_name"'" ] && export GIT_COMMITTER_NAME="'"$new_name"'"
          fi
          if [ "$GIT_AUTHOR_EMAIL" = "'"$old_email"'" ]; then
            [ -n "'"$new_email"'" ] && export GIT_AUTHOR_EMAIL="'"$new_email"'"
            [ -n "'"$new_name"'" ] && export GIT_AUTHOR_NAME="'"$new_name"'"
          fi
        fi
      fi
    fi
  ' --tag-name-filter cat -f -- --branches --tags -- "$@" &&
    git stash pop
