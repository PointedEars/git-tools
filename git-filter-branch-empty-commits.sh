#!/bin/sh
git filter-branch --commit-filter 'git_commit_non_empty_tree "$@"' HEAD
