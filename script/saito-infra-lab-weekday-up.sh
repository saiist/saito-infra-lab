#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$HOME/saito-infra-lab"
GH_REPO="saiist/saito-infra-lab"

export AWS_PROFILE="saito-dev"
export AWS_REGION="ap-northeast-1"
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

cd "$REPO_DIR"

echo "== $(date -u) START weekday-up =="

echo
echo "## whoami"
make whoami STACK=dev-core
make whoami STACK=dev-app

echo
echo "## apply (core -> app)"
make up

echo
echo "## outputs (dev-core)"
make outputs STACK=dev-core

echo
echo "## outputs (dev-app)"
make outputs STACK=dev-app

echo
echo "## resolve DB_SECRET_ARN from terraform output (dev-core)"
DB_SECRET_ARN="$(terraform -chdir=infra/envs/dev-core output -raw db_secret_arn)"
echo "db_secret_arn = ${DB_SECRET_ARN}"

echo
echo "## update GitHub Secret: DB_SECRET_ARN (requires gh auth)"
if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh not found. Install GitHub CLI or update secret manually."
  exit 1
fi

if ! gh auth status -h github.com >/dev/null 2>&1; then
  echo "ERROR: gh is not authenticated (or token invalid). Run:"
  echo "  gh auth login -h github.com"
  exit 1
fi

gh secret set DB_SECRET_ARN -R "$GH_REPO" -b"$DB_SECRET_ARN"
echo "OK: updated GitHub secret DB_SECRET_ARN for $GH_REPO"

echo
echo "== $(date -u) END weekday-up =="
