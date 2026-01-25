#!/usr/bin/env bash
set -euo pipefail

REPO="$HOME/saito-infra-lab"
LOGDIR="$HOME/logs"
mkdir -p "$LOGDIR"

export AWS_PROFILE="saito-dev"
export AWS_REGION="ap-northeast-1"
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

cd "$REPO"

# 多重起動防止
LOCKFILE="/tmp/saito-infra-lab-weekend-down.lock"
exec 9>"$LOCKFILE"
flock -n 9 || exit 0

ts="$(date -u +%Y%m%dT%H%M%SZ)"
log="$LOGDIR/weekend-down-$ts.log"

{
  echo "== $(date -u) START =="
  make destroy-auto STACK=dev-app
  make destroy-auto STACK=dev-core
  echo "== $(date -u) END =="
} |& tee -a "$log"
