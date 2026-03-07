# most-commits

Push the number of commits on a single GitHub repo as high as possible. Target: **5M+ commits** (previous record ~4M). All commits are **empty** (no file blobs) to keep metadata and repo size minimal.

## Intent

- **Goal:** Hold or beat the record for most commits in a GitHub repository.
- **Method:** Lightweight empty commits only (`git commit --allow-empty` or plumbing `commit-tree` + `update-ref`). No file content in history beyond an optional init file.
- **Scripts:** Run repeatedly (e.g. in a loop or background). Each run adds N commits to `main` in one linear chain.

## Scripts

| Script | Method | Use case |
|--------|--------|----------|
| `fast-commits.sh` | Porcelain (`git commit --allow-empty`) | Simple, minimal dependencies |
| `fast-commits-plumbing.sh` | Plumbing (`commit-tree` + `update-ref`) | Fewer operations per commit, typically 20–50% faster |

Adjust `COMMITS_PER_RUN` (or the loop bound) in the script. Recommended Git config for speed (repo-local only):

```bash
git config core.fsyncObjectFiles false
git config core.untrackedCache true
git config gc.auto 0
git config commit.gpgsign false
```

---

## Repo size and maintenance

At very high commit counts, loose objects and refs can grow a lot. Two commands are essential for understanding and cleaning the repo.

### 1. `git count-objects -vH`

**What it does:** Reports how much space the Git repo is using and where.

- **count** – Number of loose objects (not in a pack).
- **size** – Disk size of those loose objects.
- **in-pack** – Number of objects in pack file(s).
- **packs** – Number of pack files.
- **size-pack** – Disk size of pack file(s).
- **prune-packable** – Loose objects that could be removed because they exist in a pack (safe to prune).
- **garbage** / **size-garbage** – Unreferenced objects not yet pruned.

**Reference output at ~8,472,034 commits (before pruning):**

```
count: 752349
size: 2.86 GiB
in-pack: 7719690
packs: 1
size-pack: 691.86 MiB
prune-packable: 0
garbage: 0
size-garbage: 0 bytes
```

So before pruning there were 752,349 loose objects (~2.86 GiB) and 7.7M objects in one pack (~692 MiB). Running `git gc` (below) turns loose objects into packs and prunes, which you need before a reliable push.

---

### 2. `git gc --aggressive --prune=now`

**What it does:**

- **gc (garbage collection):** Packs loose objects into pack files, removes unreachable and duplicate objects, and updates the commit graph.
- **--aggressive:** More CPU/time to get better compression in the pack (smaller size, slower run).
- **--prune=now:** Prune unreachable objects immediately (don’t wait for the usual 2-week grace period).

You should run this before pushing so the repo is fully packed and pruned; otherwise the push may send huge amounts of loose objects and time out.

**Reference output (after running it):**

```
Enumerating objects: 8472039, done.
Counting objects: 100% (8472039/8472039), done.
Compressing objects: 100% (8472037/8472037), done.
Writing objects: 100% (8472039/8472039), done.
Total 8472039 (delta 8468823), reused 2986 (delta 0), pack-reused 0 (from 0)
Removing duplicate objects: 100% (256/256), done.
Expanding reachable commits in commit graph: 8472034, done.
Finding extra edges in commit graph: 100% (8472034/8472034), done.
Writing out commit graph in 4 passes: 100% (33888136/33888136), done.
```

So after GC: ~8.47M objects packed, commit graph written (8.47M commits), no loose “prune-packable” left. The repo is in a good state to push.

---

## Pushing to GitHub: timeouts and “we have to do this otherwise”

If you push **without** running `git gc --aggressive --prune=now` first, the client may send a very large number of loose objects and refs. That can lead to:

- **Operation timed out** – Connection idle or transfer too slow.
- **Broken pipe** / **send-pack: unexpected disconnect** – Server or network closes the connection while Git is still sending.

**Reference error when pushing without GC:**

```
git push origin
Enumerating objects: 438787, done.
Counting objects: 100% (438787/438787), done.
Read from remote host github.com: Operation timed out
client_loop: send disconnect: Broken pipe
send-pack: unexpected disconnect while reading sideband packet
Compressing objects: 100% (438787/438787), done.
fatal: the remote end hung up unexpectedly
```

So **you have to run `git gc --aggressive --prune=now` (and ideally wait for it to finish) before pushing.** That way:

1. Loose objects are packed into one or a few pack files.
2. The client sends a much smaller, compressed pack over the network.
3. The transfer is less likely to hit timeouts or cause the remote to hang up.

If it still times out after GC, options include:

- **Larger push buffer:** `git config http.postBuffer 524288000` (or higher).
- **Push in smaller batches:** Push a branch that’s N commits behind `main`, then push the rest in stages (advanced and repo-specific).

---

## Quick reference

| Command | Purpose |
|---------|--------|
| `git count-objects -vH` | Inspect repo size (loose vs packed). |
| `git gc --aggressive --prune=now` | Pack and prune before pushing; reduces timeouts. |
| `git rev-list --count HEAD` | Total number of commits on current branch. |
