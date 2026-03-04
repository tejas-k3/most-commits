#!/bin/sh
# 10 empty commits per run. No file blobs = minimal metadata growth.
cd "$(dirname "$0")"
i=1
while [ $i -le 10 ]; do
  git commit --allow-empty -m "c $i"
  i=$((i+1))
done
