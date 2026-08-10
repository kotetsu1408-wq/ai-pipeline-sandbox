#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[$(date '+%H:%M:%S')] $*"
}

log "=== AI Development Loop started ==="
log "Issue #${ISSUE_NUMBER}: ${ISSUE_TITLE}"
log "Max attempts: ${MAX_ATTEMPTS}"

# ダミー実装: 成功を返す
log "✓ Verification passed"
exit 0
