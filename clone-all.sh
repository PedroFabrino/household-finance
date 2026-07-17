#!/usr/bin/env bash
# clone-all.sh
# Sets up all household-finance repositories in the current directory.
# Usage: bash clone-all.sh

set -euo pipefail

REPOS=(
  "git@github.com:PedroFabrino/household-finance-api.git"
  "git@github.com:PedroFabrino/household-finance-web.git"
  # Add new repos here as new apps are created
)

echo ""
echo "==> Cloning household-finance sub-repos..."

for repo in "${REPOS[@]}"; do
  name=$(basename "$repo" .git)
  if [ -d "$name" ]; then
    echo "  [skip] $name already exists"
  else
    echo "  [clone] $name"
    git clone "$repo"
  fi
done

echo ""
echo "==> Done. Directory layout:"
ls -1d */ 2>/dev/null || true
echo ""
