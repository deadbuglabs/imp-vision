#!/bin/bash
# Push one Temple-F job's results JSON to the sweep-results branch, live,
# as soon as the job finishes — namespaced per board so it never collides
# with other lines (IMP-1 uses results/<run>/..., Temple-F uses
# results/templef/<run>/...).
#   push-results.sh <results.json> <run_number> <family> <variant>
# Uses a detached git worktree so the main checkout is untouched. Retries
# fetch+rebase+push up to 5 times (parallel jobs race on this branch; each
# job writes its own unique path, so rebase is clean).
set -euo pipefail
JSON=$1; RUN_NUMBER=$2; FAMILY=$3; VARIANT=$4
START_DIR=$(pwd)
[ -f "$JSON" ] || { echo "results file missing: $JSON"; exit 1; }
git config user.name 'github-actions[bot]'
git config user.email 'github-actions[bot]@users.noreply.github.com'
WT=/tmp/sweep-results-wt-templef
rm -rf "$WT"
if git ls-remote --exit-code --heads origin sweep-results >/dev/null 2>&1; then
  git fetch --no-tags origin refs/heads/sweep-results:refs/remotes/origin/sweep-results
else
  fetch_status=$?
  if [ "$fetch_status" -ne 2 ]; then
    echo "failed to check/fetch origin sweep-results"
    exit "$fetch_status"
  fi
fi
if git rev-parse --verify origin/sweep-results >/dev/null 2>&1; then
  git worktree add "$WT" sweep-results
else
  git worktree add --detach "$WT"
  git -C "$WT" checkout --orphan sweep-results
  git -C "$WT" read-tree --empty
  git -C "$WT" clean -fdx
fi
mkdir -p "$WT/results/templef/$RUN_NUMBER"
cp "$JSON" "$WT/results/templef/$RUN_NUMBER/${FAMILY}-${VARIANT}.json"
cd "$WT"
git add "results/templef/$RUN_NUMBER/${FAMILY}-${VARIANT}.json" || {
  echo 'git add failed'
  cd "$START_DIR"
  git worktree remove --force "$WT" 2>/dev/null
  exit 1
}
if git diff --cached --quiet; then
  echo 'nothing staged; nothing to commit'
  cd "$START_DIR"
  git worktree remove --force "$WT" 2>/dev/null
  exit 0
fi
git commit -m "templef sweep run $RUN_NUMBER: $FAMILY/$VARIANT" || {
  echo 'git commit failed'
  cd "$START_DIR"
  git worktree remove --force "$WT" 2>/dev/null
  exit 1
}
for i in 1 2 3 4 5; do
  if git push origin sweep-results; then
    echo "pushed results/templef/$RUN_NUMBER/${FAMILY}-${VARIANT}.json"
    cd "$START_DIR"
    git worktree remove --force "$WT"
    exit 0
  fi
  if [ "$i" -eq 5 ]; then
    break
  fi
  echo "push failed; rebasing before retry $((i + 1))/5"
  if ! git pull --rebase origin sweep-results; then
    git rebase --abort 2>/dev/null || true
  fi
  delay=$((1 << (i - 1)))
  jitter=$((RANDOM % (delay + 1)))
  wait_seconds=$((delay + jitter))
  echo "waiting ${wait_seconds}s before next push attempt"
  sleep "$wait_seconds"
done
echo 'push failed after 5 retries'
cd "$START_DIR"
git worktree remove --force "$WT"
exit 1
