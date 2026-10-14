#!/usr/bin/env bash
# Omarchy Scrum 2.0 — Run a Local Council seat against Ollama with cryptographic G0 proof
# and automatic injection of 01_OMARCHY_AGENT_PROMPTS.md + 00_ARCHITECTURE.md.
set -euo pipefail

ROLE="${1:-}"
if [[ -z "${ROLE}" ]]; then
  echo "usage: $0 <qweny|moxie|mitnick|jobs|scrum> [task...]" >&2
  exit 2
fi
shift || true

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK_FILE="${ROOT}/agents.lock"
if [[ ! -f "${LOCK_FILE}" ]]; then
  echo "missing ${LOCK_FILE}" >&2
  exit 1
fi

ROW="$(awk -F'|' -v s="${ROLE}" '$1 == s { print $0 }' "${LOCK_FILE}")"
if [[ -z "${ROW}" ]]; then
  echo "error: unknown seat '${ROLE}' (not in agents.lock)" >&2
  exit 2
fi
RUNTIME="$(printf '%s' "${ROW}" | cut -d'|' -f3)"
DEFAULT_MODEL="$(printf '%s' "${ROW}" | cut -d'|' -f5)"
if [[ "${RUNTIME}" != "local" ]]; then
  echo "error: seat '${ROLE}' has runtime='${RUNTIME}' in agents.lock; only local seats run via Ollama" >&2
  exit 2
fi

AGENT_FILE="${ROOT}/.cursor/agents/${ROLE}.md"
if [[ ! -f "${AGENT_FILE}" ]]; then
  echo "missing persona file: ${AGENT_FILE}" >&2
  exit 1
fi

OLLAMA_HOST="${OLLAMA_HOST:-http://127.0.0.1:11434}"
MODEL="${ANGIE_LOCAL_MODEL:-${DEFAULT_MODEL}}"
PROOF_LOG="${ANGIE_LOCAL_PROOF_LOG:-${ROOT}/.angie/local-agent-proof.log}"
mkdir -p "$(dirname "${PROOF_LOG}")"

if [[ $# -gt 0 ]]; then
  TASK="$*"
else
  TASK="$(cat)"
fi
if [[ -z "${TASK}" ]]; then
  echo "empty task packet" >&2
  exit 2
fi

export ROOT AGENT_FILE TASK MODEL
BODY_AND_HASH="$(python3 - <<'PY'
import hashlib, json, os, re
from pathlib import Path

root = Path(os.environ["ROOT"])
agent_text = Path(os.environ["AGENT_FILE"]).read_text(encoding="utf-8")
persona = re.sub(r"^---\n.*?\n---\n", "", agent_text, flags=re.S).strip()

def extract_section(path: Path, tag: str, fallback_chars: int = 6000) -> str:
    if not path.exists():
        return ""
    t = path.read_text(encoding="utf-8")
    m = re.search(rf"<!--\s*section:{tag}\s*-->(.*?)<!--\s*/section:{tag}\s*-->", t, flags=re.S)
    return m.group(1).strip() if m else t[:fallback_chars]

laws = extract_section(root / "01_OMARCHY_AGENT_PROMPTS.md", "universal-laws")
arch = extract_section(root / "00_ARCHITECTURE.md", "architecture-contracts")
task = os.environ["TASK"]

sys_prompt = "\n\n".join(filter(None, [
    persona,
    "=== CONSTITUTIONAL LAWS (01_OMARCHY_AGENT_PROMPTS.md) ===\n" + laws,
    "=== SYSTEM ARCHITECTURE & CONTRACTS (00_ARCHITECTURE.md) ===\n" + arch,
]))
packet_sha = hashlib.sha256((sys_prompt + "\n---TASK---\n" + task).encode("utf-8")).hexdigest()

body = json.dumps({
    "model": os.environ["MODEL"],
    "stream": False,
    "messages": [
        {"role": "system", "content": sys_prompt},
        {"role": "user", "content": task},
    ],
    "options": {"temperature": 0.2},
})
print(packet_sha)
print(body)
PY
)"

PACKET_SHA="$(printf '%s\n' "${BODY_AND_HASH}" | sed -n '1p')"
BODY="$(printf '%s\n' "${BODY_AND_HASH}" | sed -n '2,$p')"

RESP_FILE="$(mktemp)"
trap 'rm -f "${RESP_FILE}"' EXIT

HTTP_CODE="$(curl -sS -o "${RESP_FILE}" -w '%{http_code}' \
  -X POST "${OLLAMA_HOST}/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d "${BODY}")"

if [[ "${HTTP_CODE}" != "200" ]]; then
  echo "Ollama HTTP ${HTTP_CODE}: $(head -c 500 "${RESP_FILE}")" >&2
  exit 1
fi

python3 - <<'PY' "${RESP_FILE}" "${PROOF_LOG}" "${ROLE}" "${MODEL}" "${PACKET_SHA}" "${HTTP_CODE}"
import datetime, hashlib, json, sys
from pathlib import Path

resp_path, proof_path, role, req_model, packet_sha, http_code = sys.argv[1:7]
data = json.loads(Path(resp_path).read_text(encoding="utf-8"))
content = (
    data.get("choices", [{}])[0]
    .get("message", {})
    .get("content", "")
)
resp_model = data.get("model", "")
output_sha = hashlib.sha256(content.encode("utf-8")).hexdigest()
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

block = (
    "---\n"
    f"time={now}\n"
    f"role={role}\n"
    f"requested_model={req_model}\n"
    f"response_model={resp_model}\n"
    f"http_code={http_code}\n"
    f"packet_sha256={packet_sha}\n"
    f"output_sha256={output_sha}\n"
    f"content_chars={len(content)}\n"
)
with open(proof_path, "a", encoding="utf-8") as f:
    f.write(block)

sys.stdout.write(content)
if not content.endswith("\n"):
    sys.stdout.write("\n")
PY
