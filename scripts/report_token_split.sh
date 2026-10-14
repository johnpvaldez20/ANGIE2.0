#!/usr/bin/env bash
# Report local Ollama vs Cursor cloud agent volume from proof/ledger logs.
# Usage:
#   scripts/report_token_split.sh
#   scripts/report_token_split.sh --markdown   # write/update docs snippet path optional
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROOF="${ANGIE_LOCAL_PROOF_LOG:-${ROOT}/.angie/local-agent-proof.log}"
LEDGER="${ANGIE_CLOUD_LEDGER:-${ROOT}/.angie/cloud-agent-ledger.log}"
MARKDOWN=0
if [[ "${1:-}" == "--markdown" ]]; then
  MARKDOWN=1
fi

python3 - <<'PY' "${PROOF}" "${LEDGER}" "${MARKDOWN}" "${ROOT}"
import sys
from collections import defaultdict
from pathlib import Path

proof_path, ledger_path, markdown, root = sys.argv[1], sys.argv[2], sys.argv[3] == "1", Path(sys.argv[4])

def parse_blocks(path: Path):
    if not path.exists():
        return []
    text = path.read_text()
    blocks = []
    current = {}
    for line in text.splitlines():
        if line.strip() == "---":
            if current:
                blocks.append(current)
                current = {}
            continue
        if "=" in line:
            k, v = line.split("=", 1)
            current[k.strip()] = v.strip()
    if current:
        blocks.append(current)
    return blocks

def as_int(value, default=0):
    try:
        return int(value)
    except Exception:
        return default

local_blocks = [b for b in parse_blocks(Path(proof_path)) if b.get("http_code") == "200" or b.get("status") == "ready"]
cloud_blocks = parse_blocks(Path(ledger_path))

# Display-only folds (do not rewrite ledger/proof history).
LOCAL_DISPLAY_FOLD = {"qa": "mitnick", "gucci": "moxie"}
CLOUD_DISPLAY_FOLD = {"juan": "knuth"}
# Historical Ollama runs that used cloud seat names / legacy juan|knuth as role=
# — keep separate; do NOT fold into qweny (different model era).
LOCAL_LEGACY_ROLES = {"juan", "knuth", "linus", "dhh", "carmack"}

local_raw_calls = defaultdict(int)
local_raw_chars = defaultdict(int)
ensures = 0
for b in local_blocks:
    if b.get("event") == "ensure_local_agents":
        ensures += 1
        continue
    role = b.get("role")
    if not role:
        continue
    local_raw_calls[role] += 1
    local_raw_chars[role] += as_int(b.get("content_chars"))

local_calls = defaultdict(int)
local_chars = defaultdict(int)
legacy_calls = defaultdict(int)
legacy_chars = defaultdict(int)
for role, n in local_raw_calls.items():
    chars = local_raw_chars[role]
    if role in LOCAL_LEGACY_ROLES:
        legacy_calls[role] += n
        legacy_chars[role] += chars
        continue
    display = LOCAL_DISPLAY_FOLD.get(role, role)
    local_calls[display] += n
    local_chars[display] += chars

cloud_raw_calls = defaultdict(int)
cloud_raw_chars = defaultdict(int)
for b in cloud_blocks:
    role = b.get("role", "other")
    cloud_raw_calls[role] += 1
    cloud_raw_chars[role] += as_int(b.get("content_chars"))

cloud_calls = defaultdict(int)
cloud_chars = defaultdict(int)
for role, n in cloud_raw_calls.items():
    display = CLOUD_DISPLAY_FOLD.get(role, role)
    cloud_calls[display] += n
    cloud_chars[display] += cloud_raw_chars[role]

local_call_n = sum(local_calls.values()) + sum(legacy_calls.values())
cloud_call_n = sum(cloud_calls.values())
local_char_n = sum(local_chars.values()) + sum(legacy_chars.values())
cloud_char_n = sum(cloud_chars.values())
total_calls = local_call_n + cloud_call_n
total_chars = local_char_n + cloud_char_n

def pct(part, whole):
    if whole <= 0:
        return 0.0
    return 100.0 * part / whole

lines = []
lines.append("A.N.G.I.E. local vs cloud agent report")
lines.append(f"proof={proof_path}")
lines.append(f"ledger={ledger_path}")
lines.append("")
lines.append("LOCAL (Ollama on this Mac: qwen3.8:27b-mlx and gemma4:31b-mlx)")
lines.append(f"  ensure_ready_events={ensures}")
lines.append(f"  generation_calls={local_call_n}")
lines.append(f"  response_chars={local_char_n}  (proxy for generation volume; not tokenizer tokens)")
for role in sorted(local_calls):
    lines.append(f"    {role}: calls={local_calls[role]} chars={local_chars[role]}")
if legacy_calls:
    lines.append("  legacy_ollama_roles (excluded from qweny bucket; historical qwen3-coder / cloud-name runs):")
    for role in sorted(legacy_calls):
        lines.append(f"    {role}: calls={legacy_calls[role]} chars={legacy_chars[role]}")
lines.append("")
lines.append("CLOUD (Cursor Task / parent orchestrator ledger)")
lines.append(f"  logged_calls={cloud_call_n}")
lines.append(f"  noted_chars={cloud_char_n}  (self-reported / estimated when logged)")
for role in sorted(cloud_calls):
    lines.append(f"    {role}: calls={cloud_calls[role]} chars={cloud_chars[role]}")
lines.append("")
lines.append("SPLIT")
lines.append(f"  by_calls:  local={pct(local_call_n, total_calls):.1f}%  cloud={pct(cloud_call_n, total_calls):.1f}%  (n={total_calls})")
lines.append(f"  by_chars:  local={pct(local_char_n, total_chars):.1f}%  cloud={pct(cloud_char_n, total_chars):.1f}%  (n={total_chars})")
lines.append("")
lines.append("Notes")
lines.append("  - Local numbers are measured from Ollama proof log (http_code=200).")
lines.append("  - Display folds: local qa→mitnick, gucci→moxie; cloud juan→knuth. Ledger/proof files are not rewritten.")
lines.append("  - Legacy Ollama roles juan/knuth/linus/dhh/carmack stay on their own line — not added to qweny.")
lines.append("  - Cloud numbers only count events logged via scripts/log_cloud_agent.sh.")
lines.append("  - Parent/orchestrator coding volume is cloud unless a local runner produced it.")
lines.append("  - Planning/review: separate cloud Tasks per role; coding: local Ollama only (see 01_OMARCHY_AGENT_PROMPTS.md).")

report = "\n".join(lines)
print(report)

out = root / ".angie" / "token-split-latest.txt"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(report + "\n")

if markdown:
    md_path = root / "docs" / "TOKEN_SPLIT.md"
    md_path.parent.mkdir(parents=True, exist_ok=True)
    md = []
    md.append("# Local vs cloud agent split")
    md.append("")
    md.append("Auto-generated by `scripts/report_token_split.sh --markdown`. Do not hand-edit figures; re-run the script.")
    md.append("")
    md.append("```")
    md.append(report)
    md.append("```")
    md.append("")
    md.append("## How to update")
    md.append("")
    md.append("```bash")
    md.append("scripts/log_cloud_agent.sh linus \"review note\" [chars]")
    md.append("scripts/log_cloud_agent.sh parent \"implementation note\" [chars]")
    md.append("scripts/report_token_split.sh --markdown")
    md.append("```")
    md.append("")
    md_path.write_text("\n".join(md) + "\n")
    print(f"\nwrote {md_path}", file=sys.stderr)
PY
