#!/bin/bash

appname=${0##*/}
src_repo=$1
src_branch=$2
src_dir=${3#$src_repo}
src_file=${4#$src_repo$src_dir}

if [ -z "$src_repo" ] || [ -z "$src_branch" ] || [ -z "$src_dir" ]; then
	echo >&2 "Imports a directory/file in a branch of another repository
to the current branch of this repository, preserving the history
and relative path of the file(s).

Usage: $appname SRC_REPO SRC_BRANCH SRC_DIR [SRC_FILE]

SRC_REPO      Source repository path or URI
SRC_BRANCH    Source branch.
SRC_DIR       Source directory.  If it can be resolved to a directory in the
                local filesystem after removing the SRC_REPO prefix, that
                directory is used.
SRC_FILE      Source file path relative to SRC_DIR.  If it can be resolved
                to a file in the local filesystem after processing SRC_DIR
                as described above, that file is used."
	exit 1
fi

[ -d "$src_repo" ] && src_repo=${src_repo%/}
repo_name=${src_repo##*/}
repo_name=${repo_name%%.git*}

src_dir=${src_dir%/}

tmpdir=$(mktemp -d -q "${TMPDIR:-/tmp/}$appname-$repo_name.XXXXXXXXXXXX") || exit 1
remote="$repo_name-$src_branch"

git clone --branch "$src_branch" "$src_repo" "$tmpdir" &&
	cd "$tmpdir" &&
	git remote rm origin &&
	git filter-branch --subdirectory-filter "$src_dir" -- --all &&
	(
		if [ -n "$src_file" ]; then
			git filter-branch -f \
				--index-filter 'git ls-files -s | grep '$'\t'"$src_file"'$ | \
					GIT_INDEX_FILE=$GIT_INDEX_FILE.new git update-index --index-info && \
					mv $GIT_INDEX_FILE.new $GIT_INDEX_FILE 2>/dev/null || echo ": Nothing to do"' \
				--prune-empty \
				-- \
				--all
		fi
	) &&
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
	git commit --signoff --message="$appname: Restored filtered files to '$src_dir/'" &&
	cd - &&
	git remote add "$remote" "$tmpdir" &&
		git fetch "$remote" "$src_branch" &&
		git merge --edit --message="$appname: Merged '$src_dir/$src_file' from branch '$src_branch' of $repo_name" FETCH_HEAD &&
	git remote rm "$remote" &&
	rm -rf "$tmpdir"
