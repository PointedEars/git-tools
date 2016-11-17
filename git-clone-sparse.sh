#!/bin/sh

bold=$(tput bold 2>/dev/null)
ital=$(tput sitm 2>/dev/null)
norm=$(tput sgr0 2>/dev/null)

if [ -z "$1" ]; then
  echo >&2 "Creates a sparse clone of a repository.

$bold${0##*/}$norm ${ital}URI$norm [${ital}FETCH_PARAMS$norm]

${ital}URI$norm           Repository URI
${ital}FETCH_PARAMS$norm  See git-fetch(1) for details.
              One of the parameters that you probably want to use
              is \`--depth', specifying \"the number of commits from
              the tip of each remote branch history\".  For example,
              if you are not interested in branch histories at all
              or want to preserve a maximum of free disk space,
              specify \`--depth=1'; you can still fetch the rest
              if you change your mind later."
  exit 1
fi

origin_name='origin'
origin_uri=$1
shift
local_repo_dir=${origin_uri%.git}
local_repo_dir=${local_repo_dir##*/}

branch='master'
sparse_option='core.sparsecheckout'
sparse_config='.git/info/sparse-checkout'

if [ "$1" = '-b' ] || [ "$1" = '--branch' ]; then
  branch=$2
  shift 2
fi

if [ "$1" = '-o' ] || [ "$1" = '--origin' ]; then
  origin_name=$2
  shift 2
fi

[ -n "${1##-*}" ] && branch=$1

enable_sparse_checkout ()
{
  git config "$sparse_option" true
}

edit_sparse_config ()
{
  if [ ! -f "$sparse_config" ]; then
    echo "\
# git config "$sparse_option" true
# Paths to include in the sparse checkout, or to exclude (precede with '!').
# Lines that start with '#' are comments." > "$sparse_config"
  fi

  editor "$sparse_config" || (
    printf '\n%s\n\n' 'Sparse checkout config:'
    cat "$sparse_config"
    printf '\n%s\n' 'editor(1) not available.
Overwriting config.  Finish with Ctrl-D.'
    cat > "$sparse_config"
  )
}

if [ -d "$local_repo_dir/.git" ]; then
  cd "$local_repo_dir" &&
    enable_sparse_checkout &&
    edit_sparse_config &&
    git read-tree -mu HEAD
else
  git init "$local_repo_dir" &&
    cd "$local_repo_dir" &&
    git remote add "$origin_name" "$origin_uri" &&
    git remote -v &&
    enable_sparse_checkout &&
    git fetch "$@" "$origin_name" &&
    edit_sparse_config &&
    git pull "$origin_name" "$branch"
fi
