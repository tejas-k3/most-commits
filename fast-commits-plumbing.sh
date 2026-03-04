#!/bin/sh
#
# Plumbing version: same behavior as fast-commits.sh, fewer operations per commit.
#
# PERFORMANCE: Porcelain vs Plumbing (this script)
# -----------------------------------------------
# Porcelain (git commit --allow-empty):
#   - Reads/updates index, refreshes working tree state
#   - Can run commit-msg / post-commit hooks
#   - Extra process and parsing for "git commit"
#
# Plumbing (commit-tree + update-ref):
#   - No index; no working tree refresh
#   - No commit hooks
#   - One commit object write + one ref write per commit (minimum work)
#
# Same repo, same ref (HEAD). Run this script instead of fast-commits.sh for speed.
#
cd "$(dirname "$0")"
COMMITS_PER_RUN=100
EMPTY_TREE=4b825dc642cb6eb9a060e54bf8d69288fbee4904

PARENT=$(git rev-parse HEAD 2>/dev/null)
if [ -n "$PARENT" ]; then
  TREE=$(git rev-parse HEAD^{tree})
else
  TREE=$EMPTY_TREE
fi

i=1
while [ $i -le $COMMITS_PER_RUN ]; do
  if [ -n "$PARENT" ]; then
    NEW=$(git commit-tree $TREE -p "$PARENT" -m "c $i")
  else
    NEW=$(git commit-tree $TREE -m "c $i")
  fi
  git update-ref HEAD "$NEW"
  PARENT=$NEW
  i=$((i+1))
done
