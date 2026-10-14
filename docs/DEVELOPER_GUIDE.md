# Developer Guide & Agile Playbook

**Owner:** `knuth` (Cloud Grand Council — Donald Knuth persona; literate correctness & onboarding clarity).  
**Purpose:** Bring any human developer—or AI agent—up to speed on Day 1, and define the unified **Agile Work Breakdown Hierarchy**, **Definition of Done (DoD)**, and **QA Templates** used across the project.

---

## 1. Day-1 Quickstart

1. Read [`README.md`](../README.md) for the repository map.
2. Read [`00_ARCHITECTURE.md`](../00_ARCHITECTURE.md) for module boundaries, threading rules, and mathematical/ABI contracts.
3. Read [`docs/PRODUCT_SPEC.md`](PRODUCT_SPEC.md) for user-facing requirements (`UC-01..UC-XX`).
4. Check [`docs/SPRINT_DASHBOARD.md`](SPRINT_DASHBOARD.md) §0 for the current Sprint checkpoint and active stories.

---

## 2. The Unified Agile Work Breakdown Hierarchy (Humans & Agents)

Every feature follows one strict 5-level breakdown:

```text
Theme (Strategic Multi-Sprint Pillar)
 └── Epic (Large Multi-Sprint Body of Work)
      └── Feature (Module-Scoped Product Capability)
           └── User Story (Smallest User-Visible Unit + Given/When/Then Acceptance Criteria)
                └── Task = Rule 11 Packet (1 Atomic Coding Slice: <= 300 LOC, <= 5 files)
```

| Level | Definition | Owner |
|---|---|---|
| **Theme** | Strategic initiative or broad focus area spanning multiple milestones. | Human + Grand Council |
| **Epic** | Large body of work spanning multiple sprints that breaks down into features. | Cloud Grand Council |
| **Feature** | Distinct product capability mapped to specific source modules. | `dhh` / `linus` / `carmack` |
| **User Story** | Smallest unit of user-visible value, written with deterministic **Given-When-Then** acceptance criteria. | `dhh` + `mitnick` |
| **Task (Rule 11 Packet)** | Granular technical slice (writing a class, adding unit tests, updating a script) executed by `qweny` and peer-reviewed by `moxie`. | `qweny` + `moxie` |

---

## 3. Universal Definition of Done (DoD) Checklist

A User Story is **only** marked `Done` in [`docs/SPRINT_DASHBOARD.md`](SPRINT_DASHBOARD.md) when local `scrum` verifies all 8 criteria against Git:

- [ ] **1. Spec Link:** Linked to a `UC-XX` / `US-XX` with `Given / When / Then` acceptance criteria.
- [ ] **2. Local Provenance (`G0`):** Implemented via `scripts/run_local_agent.sh` with matching `packet_sha256` and `output_sha256` in `.angie/local-agent-proof.log`.
- [ ] **3. Testing Jig Green (`G1`):** Unit test suite 100% passing (`0` failures, `0` errors) and module coverage recorded in `docs/TESTING_JIG_REPORT.md`.
- [ ] **4. Fail-Closed Negative Tests (`G4-Test`):** `mitnick` adversarial/corrupt/missing-input tests exist and pass.
- [ ] **5. Cross-Family Peer Review (`G5`):** `moxie` (opposite local model family from coder) emitted `OMARCHY_VERDICT: APPROVE`.
- [ ] **6. Cloud Structural Gate (`G3`/`G4`):** `linus` (+ `carmack` on hot-path / `dhh` on UI) emitted `OMARCHY_VERDICT: APPROVE`.
- [ ] **7. Hardware Honesty:** Either verified on target hardware in `docs/EVIDENCE.md`, or explicitly tracked as `Device Smoke: PENDING / UNMEASURED`.
- [ ] **8. Docs Sync:** Package map and status surfaces in this guide match the code.

---

## 4. Standard Agile & QA Templates

### 4.1 User Story Template
```text
ID: US-XXX
Title:
Theme / Epic / Feature:
As a: <persona>
I want: <capability>
So that: <user-visible value>
Acceptance Criteria (Given / When / Then):
  - Given <precondition>
    When <action>
    Then <observable outcome>
Fail-Closed / Negative Case:
  - Given <missing model / corrupt file / denied permission>
    When <action>
    Then <honest refusal / sticky status, zero fabricated output>
```

### 4.2 Test Case Template
```text
ID: TC-XXX
Linked Story / Use Case: US-XXX / UC-XX
Layer: Unit (JVM) | Functional (Instrumented) | Hardware Smoke
Preconditions:
Steps:
Expected Outcome:
Actual Outcome:
Status: PASS | FAIL | BLOCKED | NOT_RUN | UNMEASURED
Evidence Link:
```

### 4.3 Defect / Bug Report Template
```text
ID: BUG-XXX
Severity: S1 (Critical) | S2 (Major) | S3 (Minor)
Priority: P1 (High) | P2 (Medium) | P3 (Low)
Summary:
Repro Steps:
Expected vs. Actual:
Environment (Commit SHA / Device / OS):
Status: OPEN | IN_PROGRESS | FIXED | VERIFIED
```

### 4.4 Sprint Test-Execution Summary Template
```text
Sprint:
Testing Jig Timestamp (UTC):
Modules Count & Overall Unit Line Coverage %:
Unit Tests (Passed / Failed / Skipped / Errors):
Hardware Smoke Rows Verified vs. UNMEASURED:
Open S1/S2 Defects:
Scrum Master Verdict:
```
