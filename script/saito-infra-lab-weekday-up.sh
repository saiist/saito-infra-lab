#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$HOME/saito-infra-lab"
GH_REPO="saiist/saito-infra-lab"

export AWS_PROFILE="saito-dev"
export AWS_REGION="ap-northeast-1"
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# SSM に保持する DB secret ARN のパラメータ名
SSM_DB_SECRET_ARN_PARAM="/saito-infra-lab/dev/db_secret_arn"

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
echo "## update SSM parameter: ${SSM_DB_SECRET_ARN_PARAM}"
DB_SECRET_ARN="$(terraform -chdir=infra/envs/dev-core output -raw db_secret_arn)"

aws ssm put-parameter \
  --region "${AWS_REGION}" \
  --name "${SSM_DB_SECRET_ARN_PARAM}" \
  --type "String" \
  --value "${DB_SECRET_ARN}" \
  --overwrite

echo
echo "== $(date -u) END weekday-up =="
