#!/bin/bash

appname=${0##*/}
bold=$(tput bold 2>/dev/null)
undl=$(tput smul 2>/dev/null)
norm=$(tput sgr0 2>/dev/null)

unset preserve_paths
if [ "$1" = '-p' ] || [ "$1" = '--preserve-paths' ]; then
	preserve_paths=1
	shift
fi

src_repo=$1
src_branch=$2
src_dir=${3#$src_repo}

if [ -z "$src_repo" ] || [ -z "$src_branch" ] || [ -z "$src_dir" ]; then
	echo >&2 "Imports a directory/file from a branch of another repository.

Usage: $bold$appname$norm [$bold-p$norm] ${undl}SRC_REPO$norm ${undl}SRC_BRANCH$norm ${undl}SRC_DIR$norm [${undl}SRC_FILE$norm...]

Imports a directory/file(s) from a branch of another repository
to the current branch of this repository, preserving its history
and optionally its/their relative path.

This is accomplished as follows:

  1. Clone the other repository to a temporary directory, and switch to
     the branch from which files should be imported; see ${bold}git-clone$norm(1).
  2. Filter that branch, rewriting history; see ${bold}git-filter-branch$norm(1):
     a) Discard everything except files in or under ${bold}SRC_DIR$norm.
     b) Discard all files except ${bold}SRC_FILE$norm.
  3. Optionally, restore the directory structure and commit any changes
     to the local repository only; see ${bold}git-mv$norm(1) and ${bold}git-commit$norm(1).
  4. Add the clone as remote of the target repository; see ${bold}git-remote$norm(1).
  5. Fetch the new remote into a new branch; see ${bold}git-fetch$norm(1).
  6. Merge the new branch into the current branch; see ${bold}git-merge$norm(1).
  7. Clean up.

${bold}OPTIONS$norm

  ${bold}-p$norm, $bold--preserve-paths$norm
    Preserve the full relative paths of source files.
    If not specified, the common ancestor of source files is used as
    the project root.
    NOTE: You MUST use this option if you want to import several files
    with the same filename from different directories.  Otherwise
    the final merge will fail and may import other files in those directories.

${bold}PARAMETERS$norm

  ${undl}SRC_REPO$norm      Source repository path or URI
  ${undl}SRC_BRANCH$norm    Source branch
  ${undl}SRC_DIR$norm       Source directory.  If it can be resolved to a directory in
                the local filesystem after removing the ${undl}SRC_REPO$norm prefix,
                that directory is used.
  ${undl}SRC_FILE$norm      Source file paths relative to ${undl}SRC_DIR$norm.  If they can be resolved
                to files in the local filesystem after processing ${undl}SRC_DIR$norm
                as described above, those files are used."
	exit 1
fi

[ -d "$src_repo" ] && src_repo=${src_repo%/}
repo_name=${src_repo##*/}
repo_name=${repo_name%%.git*}

src_dir=${src_dir%/}

rx_escape ()
{
	(
		escape_char=${2:-/}
		printf '%s' "${1//$escape_char/\\$escape_char}"
	)
}

shift 3
for src_file in "$@"
do
	[ -n "$src_files" ] && src_files="$src_files|"
	src_file=${src_file#$src_repo/}
	src_file=${src_file#$src_dir}
	src_file=${src_file##/}
	src_files=$src_files${src_file}
done

tmpdir=$(mktemp -d -q "${TMPDIR:-/tmp/}$appname-$repo_name.XXXXXXXXXXXX") || exit 1
remote="$repo_name-$src_branch"

git clone --branch "$src_branch" "$src_repo" "$tmpdir" &&
	cd "$tmpdir" &&
	git remote rm origin &&
	git filter-branch --subdirectory-filter "$src_dir" -- --all &&
	(
		if [ -n "$src_files" ]; then
			git filter-branch -f \
				--index-filter 'git ls-files -s | egrep '\'$'\t'"($src_files)"'$'\'' | \
					GIT_INDEX_FILE=$GIT_INDEX_FILE.new git update-index --index-info && \
					mv $GIT_INDEX_FILE.new $GIT_INDEX_FILE 2>/dev/null || echo ": Nothing to do"' \
				--prune-empty \
				-- \
				--all
		fi
	) &&
	(
		if [ $preserve_paths ]; then
			mkdir -p -- "$src_dir" &&
				(
					for file in *
					do
						if [ -e "$file" ] && [ "${src_dir#$file}" = "$src_dir" ]; then
							git mv -- "$file" "$src_dir"
						fi
					done
				) &&
				git add --all . &&
				git commit --signoff --message="$appname: Restored filtered files to '$src_dir/'"
		fi
	) &&
	cd - &&
	git remote add "$remote" "$tmpdir" &&
		git fetch "$remote" "$src_branch" &&
		(
			git merge --edit --message="$appname: Merged '$src_dir/$src_files' from branch '$src_branch' of $repo_name" FETCH_HEAD ||
			(
				printf >&2 "\n${bold}Merge failed because something went wrong.  Once you fixed it, run

git merge --edit --message=\"$appname: Merged '$src_dir/$src_files' from branch '$src_branch' of $repo_name\" FETCH_HEAD &&
  git remote rm \"$remote\" &&
  rm -rf \"$tmpdir\"

or something to that effect in order to complete the import.$norm\n"
				exit 1
			)
		) &&
	git remote rm "$remote"
	[ ! $debug ] && rm -rf "$tmpdir"
