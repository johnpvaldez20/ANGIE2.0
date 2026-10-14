# ANGIE 2.0 — Repository Entry & Table of Contents

This is the **ANGIE 2.0** repository (`https://github.com/johnpvaldez20/ANGIE2.0.git`), initialized from the **Omarchy Scrum 2.0** Universal Multi-Agent Software Engineering Blueprint (`psychic-parakeet`).

---

## 1. How the Core Documents Work Together

```text
README.md (You are here: TOC, versioning, release workflow, quickstart)
 ├── 00_ARCHITECTURE.md          → HOW ANGIE 2.0 is engineered (modules, threads, ABIs, math contracts)
 ├── 01_OMARCHY_AGENT_PROMPTS.md → HOW agents work together (12 Iron Laws, Gates G0–G5, Rule 11 packets)
 ├── 02_PRODUCTION_PLAN.md       → High-level phased roadmap from Day 0 to production release
 ├── AGENTS.md (+ agents.lock)   → WHO the agents are (Personas, cognitive weights, runtime bindings)
 └── docs/
      ├── PRODUCT_SPEC.md                → Complete ANGIE 2.0 Product & Runtime Spec (UC-01..UC-13, Layers 0–3)
      ├── OMARCHY_SCRUM_2_0_BLUEPRINT.md → Universal Multi-Agent Software Engineering Blueprint
      ├── DEVELOPER_GUIDE.md             → Human onboarding, package map, Agile hierarchy & DoD templates
      ├── SPRINT_DASHBOARD.md            → Living Sprint state, checkpoint, Executive & Team metrics
      ├── TESTING_JIG_REPORT.md          → Auto-generated module coverage & UC traceability readout
      ├── EVIDENCE.md                    → Measured hardware & integration rows only (no guesses)
      └── HISTORY.md                     → Append-only chronological milestone log
```

---

## 2. Complete Markdown Table of Contents

| File | Layer | Owner | Role |
|---|---|---|---|
| [`README.md`](README.md) | Entry | `knuth` (intent) / `qweny` (edits) | Table of contents, versioning, release gates, how the core files fit together |
| [`00_ARCHITECTURE.md`](00_ARCHITECTURE.md) | L0 Architecture | Cloud Grand Council (`linus` chair) | System architecture, module boundaries, threading, and code-owned mathematical/ABI contracts. **No agent rules; no daily sprint state.** |
| [`01_OMARCHY_AGENT_PROMPTS.md`](01_OMARCHY_AGENT_PROMPTS.md) | L0 Agent Constitution | Cloud Grand Council | The 12 Iron Laws, Cloud vs. Local hemisphere routing, Rule 11 packet format, Merge Gates `G0–G5`, machine-parseable `OMARCHY_VERDICT:` schema, and Tiered Quorum. **No product domain code.** |
| [`02_PRODUCTION_PLAN.md`](02_PRODUCTION_PLAN.md) | L0 Macro Plan | Cloud Grand Council | Phased roadmap (`Phase 0` through `Phase 5`) to take ANGIE 2.0 from bootstrap to production. |
| [`AGENTS.md`](AGENTS.md) & [`agents.lock`](agents.lock) | L0 Identity | `parent` + `linus` | Canonical Persona Seat → Cognitive Weight → Runtime/Model table (`agents.lock` is the single machine-readable source of truth). |
| [`docs/PRODUCT_SPEC.md`](docs/PRODUCT_SPEC.md) | L1 Product | `dhh` | Complete standalone ANGIE 2.0 product & runtime specification (`UC-01..UC-13`, Layers 0–3, languages, permissions). |
| [`docs/OMARCHY_SCRUM_2_0_BLUEPRINT.md`](docs/OMARCHY_SCRUM_2_0_BLUEPRINT.md) | L0 Blueprint | Visionary / Scrum | Universal Multi-Agent Software Engineering Blueprint. |
| [`docs/DEVELOPER_GUIDE.md`](docs/DEVELOPER_GUIDE.md) | L2 Onboarding | `knuth` | Day-1 human developer guide, Agile hierarchy (`Theme → Epic → Feature → Story → Task`), DoD, and QA templates. |
| [`docs/SPRINT_DASHBOARD.md`](docs/SPRINT_DASHBOARD.md) | L3 Living State | `scrum` + `parent` | Session resume checkpoint, active Sprint backlog, Executive & Team views (`UNMEASURED` where silent). |
| [`docs/TESTING_JIG_REPORT.md`](docs/TESTING_JIG_REPORT.md) | L6 Generated | Testing Jig script | Auto-generated module count, unit/functional coverage %, UC linkage, and release test totals. |
| [`docs/EVIDENCE.md`](docs/EVIDENCE.md) | L3 Results | `mitnick` + human | Timestamped hardware smoke & integration measurements only. |
| [`docs/HISTORY.md`](docs/HISTORY.md) | L3 Log | `parent` | Append-only dated log of completed milestones. |
| [`docs/GRAND_COUNCIL.md`](docs/GRAND_COUNCIL.md) | L3 Governance | Cloud Grand Council | Index of independent Nobel milestone ballots. |

---

## 3. Versioning & Release Workflow

1. **Semantic Versioning:** Application version follows `MAJOR.MINOR.PATCH` (`0.1.0` at bootstrap). Documentation history is tracked via Git commits and append-only rows in [`docs/HISTORY.md`](docs/HISTORY.md).
2. **Detector Artifact Versioning:** On-device ML weights are never committed to Git. Each exported detector is published as an immutable release tag (`detector-<id>-v1`, `v2`, …) pinned by 64-hex SHA-256 and exact byte length in `models.lock`. Mutating bytes under an existing tag is forbidden.
3. **Release Gate (Rule 16):** Before cutting any version tag or merging a milestone branch:
   - `./gradlew :app:testingJig` must report `0` unit failures and `100%` UC linkage.
   - Local `scrum` audits [`docs/SPRINT_DASHBOARD.md`](docs/SPRINT_DASHBOARD.md) for Definition-of-Done compliance and ensures unverified hardware items remain marked `UNMEASURED`.
   - The **Cloud Grand Council** (`linus`, `dhh`, `carmack`, `knuth`) and **Local Council** (`qweny`, `moxie`, `mitnick`, `scrum`) cast independent Nobel ballots (`SHIP` / `SHIP_WITH_FIXES` / `HOLD`).

---

## 4. Day-0 Quickstart

```bash
# 1. Verify local two-family Ollama readiness (Family A: qwen3.8, Family B: gemma4)
scripts/ensure_local_agents.sh

# 2. Run a local coding / review / scrum seat (auto-injects 01_ laws + 00_ architecture)
scripts/run_local_agent.sh qweny   "Task packet..."
scripts/run_local_agent.sh moxie   "G5 peer review..."
scripts/run_local_agent.sh mitnick "Adversarial test plan..."
scripts/run_local_agent.sh scrum   "Audit SPRINT_DASHBOARD.md against git"

# 3. Refresh local vs. cloud token split
scripts/report_token_split.sh --markdown
```
