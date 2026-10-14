#!/usr/bin/env bash
# Cold-start bootstrap for Omarchy Scrum 2.0 local seats (reads models from agents.lock).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK_FILE="${ROOT}/agents.lock"
OLLAMA_HOST="${OLLAMA_HOST:-http://127.0.0.1:11434}"
PROOF_DIR="${ROOT}/.angie"
mkdir -p "${PROOF_DIR}"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
command -v ollama >/dev/null 2>&1 || fail "ollama not on PATH"
command -v curl >/dev/null 2>&1 || fail "curl required"
command -v python3 >/dev/null 2>&1 || fail "python3 required"

ready=0
for _ in $(seq 1 30); do
  if curl -fsS "${OLLAMA_HOST}/api/tags" >/dev/null 2>&1; then
    ready=1
    break
  fi
  if ! pgrep -x ollama >/dev/null 2>&1; then
    nohup ollama serve >/dev/null 2>&1 &
  fi
  sleep 1
done
[[ "${ready}" -eq 1 ]] || fail "Ollama not reachable at ${OLLAMA_HOST}"

TAGS_JSON="$(curl -fsS "${OLLAMA_HOST}/api/tags")"
export TAGS_JSON LOCK_FILE
python3 - <<'PY'
import json, os, sys
from pathlib import Path

names = {m.get("name", "") for m in json.loads(os.environ["TAGS_JSON"]).get("models", [])}
needed = sorted({
    line.split("|")[4].strip()
    for line in Path(os.environ["LOCK_FILE"]).read_text().splitlines()
    if "|" in line and not line.startswith("#") and line.split("|")[2].strip() == "local"
})
missing = [m for m in needed if m not in names and f"{m}:latest" not in names]
if missing:
    print("ERROR: missing local models in Ollama: " + ", ".join(missing), file=sys.stderr)
    for m in missing:
        print(f"  ollama pull {m}", file=sys.stderr)
    sys.exit(1)
print("local_models_ok: " + ", ".join(needed))
PY
