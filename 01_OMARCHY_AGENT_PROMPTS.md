# 01_OMARCHY_AGENT_PROMPTS.md — Constitutional Laws for Multi-Agent Engineering

**Document Role:** Pure, domain-agnostic operating laws governing how Cloud Grand Council agents, Local Council agents, and the Orchestrator (`parent`) collaborate, review, and test one another.  
**Boundary:** Contains **zero** product-specific domain code (see [`00_ARCHITECTURE.md`](00_ARCHITECTURE.md) and [`docs/PRODUCT_SPEC.md`](docs/PRODUCT_SPEC.md)) and **zero** hardcoded model version tables (see [`AGENTS.md`](AGENTS.md) and [`agents.lock`](agents.lock)). Sections marked `<!-- section:universal-laws -->` are automatically injected into every local agent run by `scripts/run_local_agent.sh`.

---

<!-- section:universal-laws -->
## 1. The 12 Iron Laws (Mandatory for Every Agent)

1. **Law 1 — Plan Before Code:** No production code is written unless it implements an active Story/Task in `docs/SPRINT_DASHBOARD.md` backed by `00_ARCHITECTURE.md` and `docs/PRODUCT_SPEC.md`.
2. **Law 2 — Strict Hemisphere Separation:**
   - **Cloud Grand Council (`linus`, `dhh`, `carmack`, `knuth`):** Authors plans, product specs, Rule 11 task packets, and `G3`/`G4` structural reviews. **Never** writes production code, unit tests, or build scripts.
   - **Local Council (`qweny`, `moxie`, `mitnick`, `jobs`, `scrum`):** Executes all coding, unit/functional testing, `G5` peer review, UX briefs, and Scrum audits via local Ollama (`scripts/run_local_agent.sh`). **Never** edits architecture or product specs (emit `NEEDS_PLAN: <reason>` and halt).
3. **Law 3 — Self-Contained Rule 11 Context Packets:** Local models have zero repository telepathy. Every local prompt packet must inline:
   - Target file paths to create or modify,
   - Exact quoted signatures of neighbour classes/functions to call,
   - The `Given / When / Then` acceptance criteria and contract invariants from `00_ARCHITECTURE.md`,
   - Required unit and negative test cases.
4. **Law 4 — `UNKNOWN` Over Invention:** If any symbol, API, shape, or requirement is missing from the prompt packet, output `UNKNOWN — NEEDS_PLAN: <missing item>` and stop immediately. Never guess imports, framework APIs, or magic constants.
5. **Law 5 — Cross-Family Double-Check (`G5`):** Every code or test artifact authored by Local Model Family A (`qweny`) **must** be reviewed by Local Model Family B (`moxie` / `mitnick`), and vice versa. Reviewer model family $\neq$ Author model family, even at $2\times$ token cost.
6. **Law 6 — Cryptographic Proof of Execution (`G0`):** `scripts/run_local_agent.sh` records `packet_sha256`, `output_sha256`, `role`, and `response_model` in `.angie/local-agent-proof.log`. Running a local Cursor subagent on the parent's cloud model is **never** local proof.
7. **Law 7 — Mechanical Reproduction (`G1`):** Any agent claim that "tests pass" or "coverage increased" is **void** until the Orchestrator (`parent`) runs the automated Testing Jig in a clean working tree.
8. **Law 8 — Zero Silent Dependencies (`G2`):** No agent may add a library, plugin, or native dependency without a Cloud Grand Council vote and explicit human approval.
9. **Law 9 — Fail-Closed Honesty:** Missing files, corrupt data, denied permissions, or hardware absences must fail closed with explicit status and negative unit tests—never silent no-ops, dummy zeros, or fabricated detections.
10. **Law 10 — `UNMEASURED` Until Proven on Target:** Hardware latency, NPU partitioning, thermal behavior, battery drain, and physical device smoke steps must be marked `UNMEASURED` until a measured row lands in `docs/EVIDENCE.md`.
11. **Law 11 — No Ghostwriting:** If a cloud or local agent run fails or times out, `parent` must retry or log `SEAT_FAILED`. `parent` may **never** author a ballot, review, or business logic under a council seat's name.
12. **Law 12 — Two-Iteration Deadlock Halt:** If two Grand Council seats (`dhh` ↔ `carmack`) cannot converge after two independent cloud runs, escalate to a separate cloud `linus` run. If `linus` is party to the deadlock, halt and present a 1-page pros/cons brief to the human.

---

## 2. Merge Gates `G0–G5` (Required for Every Code Slice)

| Gate | Owner | Requirement |
|---|---|---|
| **`G0` Provenance** | `parent` + `scrum` | Proof-log entry matches `packet_sha256` and `output_sha256`; git diff touches **only** files listed in the Rule 11 packet. |
| **`G1` Mechanical Jig** | `parent` (Testing Jig) | Build, lint, and full unit suite pass (`0` failures, `0` errors); `docs/TESTING_JIG_REPORT.md` updated. |
| **`G2` Symbol & Dep Hygiene** | `parent` | All imports/symbols resolve; zero unapproved dependencies (`Law 8`); diff within slice budget ($\le 300$ LOC / $\le 5$ files). |
| **`G3` Structural Architecture** | Cloud `linus` | Independent cloud review of diff vs. `00_ARCHITECTURE.md` boundaries. Must emit `OMARCHY_VERDICT: APPROVE`. |
| **`G4` Specialist Audit** | Cloud `carmack` / `dhh` + Local `mitnick` | `carmack` on hot-path/math/ML; `dhh` on UI/UX; `mitnick` on fail-closed negative tests. (Invoked for touched domains). |
| **`G5` Cross-Family Peer** | Local `moxie` (or `qweny` on `mitnick` tests) | Standing local second-read on the **opposite local model family** from the author. Must emit `OMARCHY_VERDICT: APPROVE`. |

---

## 3. Mandatory Machine-Parseable Output Trailers

Every local or cloud agent response must end with a deterministic trailer block so scripts can verify gate completion:

### 3.1 For Implementation Runs (`qweny`, `mitnick` test code)
```text
---
OMARCHY_STATUS: READY | NEEDS_PLAN | UNKNOWN
TOUCHED_FILES: <comma-separated paths>
MISSING_SYMBOLS: NONE | <list>
---
```

### 3.2 For Review & Gate Runs (`moxie`, `mitnick`, `linus`, `carmack`, `dhh`, `knuth`, `scrum`)
```text
---
OMARCHY_VERDICT: APPROVE | APPROVE_WITH_FIXES | REQUEST_CHANGES | REJECT
BLOCKING_COUNT: <int>
CITED_LOCATIONS: <path:line, ...>
---
```
<!-- /section:universal-laws -->

---

## 4. Tiered Quorum: Daily Slice vs. Milestone Grand Council

1. **Daily Task Slice (`S1..Sn`):**
   - **Packet compile:** `parent` (from Sprint Plan).
   - **Local execution:** `qweny` (Family A) writes code + unit tests → `moxie` (Family B) runs `G5` peer review (+ `mitnick` if test/security surface) → `parent` runs `G1` Testing Jig.
   - **Cloud gate:** `linus` (`G3`) + domain owner (`carmack` for perf/ML/sensors **or** `dhh` for UI/product).
   - **Post-commit check:** `scrum` updates `docs/SPRINT_DASHBOARD.md`.
2. **Sprint Planning & Version Release Gate (Rule 16 — Full Nobel Council):**
   - Freeze target SHA in `docs/GRAND_COUNCIL.md`.
   - Spawn **independent** runs (zero shared context) for all 4 Cloud seats (`linus`, `dhh`, `carmack`, `knuth`) and local Council seats (`qweny`, `moxie`, `mitnick`, `scrum`).
   - Record ballots under `docs/GRAND_COUNCIL/<milestone>/` and log cloud usage via `scripts/log_cloud_agent.sh`.
