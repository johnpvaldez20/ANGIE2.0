# Sprint Dashboard (Living State & Empirical Metrics)

**Honesty Rule (Law 10):** Every cell in this dashboard must cite a verifiable source (`TESTING_JIG_REPORT.md @ <timestamp>`, `EVIDENCE.md#<row>`, or `git commit <sha>`). Any metric without a backing store must read **`UNMEASURED`** — never `0`, `0%`, or fabricated progress.

**Audited by:** `scripts/run_local_agent.sh scrum`

---

## 0. Session Resume Checkpoint (Overwrite in Place)

| Field | Current Value |
|---|---|
| **Active Sprint** | Sprint 1 — Bootstrap & Phase 1 Core |
| **Current Status** | Day-0 repository initialized with Omarchy Scrum 2.0 governance & templates |
| **Next Action** | Convene Cloud Grand Council on `docs/PRODUCT_SPEC.md` + `00_ARCHITECTURE.md` to emit Sprint 1 Rule 11 Task Packets (`S1..Sn`), wire Testing Jig, and begin local execution |
| **Blockers** | None |

---

## 1. Executive / Release Decision View (Macro Stability & Risk)

| Widget | Value | Backing Source |
|---|---|---|
| **Release Test Health (Unit)** | **UNMEASURED** (run Testing Jig) | `docs/TESTING_JIG_REPORT.md` |
| **Release Test Health (Functional / Device)** | **UNMEASURED** | `docs/EVIDENCE.md` |
| **Use-Case Readiness Breakdown** | `0` Device Proven · `0` JVM Tested · `0` In Progress · All Pending Sprint 1 | `docs/TESTING_JIG_REPORT.md` |
| **Definition of Done (DoD) Compliance** | **UNMEASURED** | `scrum` audit of active sprint stories |
| **Defect Density & Leakage Rate** | **UNMEASURED** | No defect log rows yet |
| **Active Defect Matrix (`S1..S3 × P1..P3`)** | **UNMEASURED** (empty matrix, not zeros) | — |
| **Mean Time to Resolve (MTTR)** | **UNMEASURED** | — |
| **Automation Coverage vs. Manual** | Unit: **UNMEASURED** · Device/Manual: **UNMEASURED** | `docs/TESTING_JIG_REPORT.md` |
| **CI / Pipeline Health** | **UNMEASURED** | No `.github/workflows` configured yet |
| **Local vs. Cloud Token Split** | **UNMEASURED** (run `scripts/report_token_split.sh --markdown`) | `docs/TOKEN_SPLIT.md` |

---

## 2. Team / Standup Execution View (Micro Blockers & Daily Progress)

### 2.1 Active Sprint Story Readiness Pipeline

| Story ID | Title | Use Case | State (`Needs Plan` / `Packet Ready` / `In Local Coding` / `In G5/G3` / `Ready for Smoke` / `Done`) | DoD (8/8) |
|---|---|---|---|---|
| `US-00` | Wire Automated Testing Jig & Coverage Readout | Infrastructure | `Needs Plan` | 0/8 |

### 2.2 Testing Burnup / Burndown
- **UNMEASURED** until Sprint 1 task packets (`S1..Sn`) are locked.

### 2.3 Per-Module Coverage & Thin-Spot Alerts
- Run `./gradlew :app:testingJig` (or project equivalent) to populate module coverage from `docs/TESTING_JIG_REPORT.md`.
