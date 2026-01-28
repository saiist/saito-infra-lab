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
echo "== $(date -u) END weekday-up =="
