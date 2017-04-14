#!/bin/sh
## git-root -- outputs the current Git repository's root directory
## Copyright (c) 2016  Thomas 'PointedEars' Lahn <PointedEars@web.de>.
## Distributed under the GNU General Public License, version 3 (GPLv3).
##
## Make it executable, symlink it as `git-root' in a directory in your PATH,
## and execute
##
## export PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND'; '}"' [ -n "$(which git-root)" ] && export GIT_ROOT=$(git root --relative 2>/dev/null)'
##
## when initialising the shell (e.g. in .bashrc) for a GIT_ROOT
## environment variable that always has the current git root directory relative path
## as its value.  You can then write, e.g.,
##
## cd $GIT_ROOT
##
## to change to the Git root directory, observing symlinks (without `--relative',
## the absolute path is output).

if git rev-parse >/dev/null 2>&1; then
  if [ "$1" = '--relative' ]; then
    git rev-parse --show-cdup
  else
    git rev-parse --show-toplevel
  fi
fi
