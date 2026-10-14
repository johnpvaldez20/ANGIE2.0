#!/usr/bin/env bash
# Append a Cloud Grand Council or Orchestrator event to .angie/cloud-agent-ledger.log
set -euo pipefail

ROLE="${1:-}"
NOTE="${2:-}"
CHARS="${3:-0}"
if [[ -z "${ROLE}" || -z "${NOTE}" ]]; then
  echo "usage: $0 <linus|dhh|carmack|knuth|parent> \"note + run id\" [content_chars]" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK_FILE="${ROOT}/agents.lock"
ROW="$(awk -F'|' -v s="${ROLE}" '$1 == s { print $0 }' "${LOCK_FILE}")"
if [[ -z "${ROW}" ]]; then
  echo "error: unknown seat '${ROLE}' (not in agents.lock)" >&2
  exit 2
fi
RUNTIME="$(printf '%s' "${ROW}" | cut -d'|' -f3)"
if [[ "${RUNTIME}" == "local" ]]; then
  echo "error: '${ROLE}' is a local seat; use scripts/run_local_agent.sh ${ROLE}" >&2
  exit 2
fi

LEDGER="${ANGIE_CLOUD_LEDGER:-${ROOT}/.angie/cloud-agent-ledger.log}"
mkdir -p "$(dirname "${LEDGER}")"
{
  echo "---"
  echo "time=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "role=${ROLE}"
  echo "source=cursor_cloud"
  echo "note=${NOTE}"
  echo "content_chars=${CHARS}"
} >>"${LEDGER}"
echo "cloud ledger += role=${ROLE} chars=${CHARS}"
