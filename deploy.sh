#!/usr/bin/env bash
# Build the site here and publish the static output to the `deploy` branch.
# The nginx server only needs: git pull (on a clone of the deploy branch).
set -euo pipefail
cd "$(dirname "$0")"

if [[ -n "$(git status --porcelain)" ]]; then
	echo "Uncommitted changes in main — commit them first." >&2
	exit 1
fi

npm run build

SRC_SHA=$(git rev-parse --short HEAD)
WT=.deploy

if [[ ! -d $WT ]]; then
	if git ls-remote --exit-code --heads origin deploy >/dev/null 2>&1; then
		git fetch -q origin deploy
		git worktree add -q -B deploy "$WT" origin/deploy
	else
		git worktree add -q --orphan -b deploy "$WT"
	fi
fi

git -C "$WT" pull -q --ff-only origin deploy 2>/dev/null || true
rsync -a --delete --exclude .git .vitepress/dist/ "$WT"/

git -C "$WT" add -A
if git -C "$WT" diff --cached --quiet; then
	echo "No changes to deploy."
else
	git -C "$WT" commit -q -m "deploy: build of main@$SRC_SHA"
	echo "Committed build of main@$SRC_SHA"
fi
git -C "$WT" push -q -u origin deploy
echo "Pushed. On the server: cd /var/www/smarterp && git pull"
