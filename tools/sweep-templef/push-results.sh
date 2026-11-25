#!/bin/bash
# Push one Temple-F job's results JSON to the sweep-results branch, live,
# as soon as the job finishes — namespaced per board so it never collides
# with other lines (IMP-1 uses results/<run>/..., Temple-F uses
# results/templef/<run>/...).
#   push-results.sh <results.json> <run_number> <family> <variant>
# Uses a detached git worktree so the main checkout is untouched. Retries
# fetch+rebase+push up to 5 times (parallel jobs race on this branch; each
# job writes its own unique path, so rebase is clean).
set -u
JSON=$1; RUN_NUMBER=$2; FAMILY=$3; VARIANT=$4
START_DIR=$(pwd)
[ -f "$JSON" ] || { echo "results file missing: $JSON"; exit 1; }
git config user.name 'github-actions[bot]'
git config user.email 'github-actions[bot]@users.noreply.github.com'
WT=/tmp/sweep-results-wt-templef
rm -rf "$WT"
git fetch origin sweep-results 2>/dev/null || true
if git rev-parse --verify origin/sweep-results >/dev/null 2>&1; then
  git worktree add "$WT" sweep-results
else
  git worktree add --detach "$WT"
  git -C "$WT" checkout --orphan sweep-results
  git -C "$WT" rm -rf . 2>/dev/null || true
fi
mkdir -p "$WT/results/templef/$RUN_NUMBER"
cp "$JSON" "$WT/results/templef/$RUN_NUMBER/${FAMILY}-${VARIANT}.json"
cd "$WT"
git add "results/templef/$RUN_NUMBER/${FAMILY}-${VARIANT}.json"
git commit -m "templef sweep run $RUN_NUMBER: $FAMILY/$VARIANT" || { echo 'nothing to commit'; cd "$START_DIR"; git worktree remove --force "$WT" 2>/dev/null; exit 0; }
for i in 1 2 3 4 5; do
  if git push origin sweep-results; then
    echo "pushed results/templef/$RUN_NUMBER/${FAMILY}-${VARIANT}.json"
    cd "$START_DIR"
    git worktree remove --force "$WT"
    exit 0
  fi
  echo "push conflict, retry $i/5"
  git pull --rebase origin sweep-results || git rebase --abort
done
echo 'push failed after 5 retries'
cd "$START_DIR"
git worktree remove --force "$WT"
exit 1
