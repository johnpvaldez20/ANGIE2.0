# AGENTS.md — Canonical Personas, Cognitive Weights, and Runtime Bindings

**Single Source of Truth:** Machine-readable bindings live in [`agents.lock`](agents.lock). System architecture lives in [`00_ARCHITECTURE.md`](00_ARCHITECTURE.md). Agent behavior laws live in [`01_OMARCHY_AGENT_PROMPTS.md`](01_OMARCHY_AGENT_PROMPTS.md). Macro roadmap lives in [`02_PRODUCTION_PLAN.md`](02_PRODUCTION_PLAN.md). Product requirements live in [`docs/PRODUCT_SPEC.md`](docs/PRODUCT_SPEC.md).

---

## 1. Token Routing & Hemisphere Split

**Cloud Grand Council = High-Context Planning & Structural Review.**  
**Local Council = All Code, Unit Tests, Adversarial QA, UX Briefs & Scrum Audits.**

| Artifact Class | Permitted Hemisphere | Mechanism | Proof Required |
|---|---|---|---|
| Architecture (`00_`), Agent Laws (`01_`), Roadmap (`02_`), `PRODUCT_SPEC.md`, `G3`/`G4` Reviews, Grand Council Ballots | **Cloud Grand Council** (`linus`, `dhh`, `carmack`, `knuth`) | Separate Cursor Cloud Task per seat (distinct model family) | `scripts/log_cloud_agent.sh <seat>` + cloud run ID |
| Production code (`app/**`, `src/**`), unit/functional tests, build scripts, Testing Jig, Scrum audits | **Local Council** (`qweny`, `moxie`, `mitnick`, `jobs`, `scrum`) | `scripts/run_local_agent.sh <seat>` against local Ollama | `.angie/local-agent-proof.log` (`packet_sha256` + `output_sha256` + `response_model`) |
| Packet compilation, applying local diffs, running the Testing Jig (`G1`) | **Orchestrator** (`parent`) | Host session | Git commit + `TESTING_JIG_REPORT.md` |

---

## 2. Canonical Seat Table (Abstracted Personas → Bound Models)

Workflows and prompts reference **only the Seat ID**, never a hardcoded model version. When a newer model is released, update [`agents.lock`](agents.lock) after a 1-task cook-off.

<!-- seat-table:canonical -->
| Seat ID | Archetype Persona | Cognitive Weight (Why This Seat Exists) | Group | Permitted Runtime | Family / Default Model (`agents.lock`) |
|---|---|---|---|---|---|
| **`linus`** | **Linus Torvalds** | **Chief Architect (`G3`).** Kernel-grade intolerance for broken boundaries, over-abstraction, bloated diffs, and hidden errors. | Grand Council | Cloud Task | Cloud Family 1 · `claude-opus-5-5-high` |
| **`dhh`** | **David Heinemeier Hansson** | **Product & UI Lead (`G4-UI`).** Conceptual compression; status lines over dashboards; hates ceremony and premature DI. | Grand Council | Cloud Task | Cloud Family 2 · `muse-spark-1.3-high` |
| **`carmack`** | **John Carmack** | **Performance & Engine Lead (`G4-Perf`).** id Tech math rigor; zero frame-loop allocations; refuses unmeasured hardware claims. | Grand Council | Cloud Task | Cloud Family 3 · `grok-4.7-high` |
| **`knuth`** | **Donald Ervin Knuth** | **Algorithmic Rigor & Onboarding.** TAOCP correctness, formal invariants, $O(1)$ vs amortized honesty, `DEVELOPER_GUIDE.md`. | Grand Council | Cloud Task | Cloud Family 4 · `gpt-5.6-sol-high` |
| **`qweny`** | **Primary Builder** | **Lead Local Implementer.** Translates Rule 11 packets into clean code and unit tests; outputs `UNKNOWN`/`NEEDS_PLAN` instead of guessing. | Local Council | Local Ollama | **Local Family A** · `qwen3.8:27b-mlx` |
| **`moxie`** | **Moxie Marlinspike** | **Standing Peer Reviewer (`G5`) & Privacy.** Distrusts complex trust; hunts TOCTOU, cleartext, session leaks, and silent fallbacks. | Local Council | Local Ollama | **Local Family B** · `gemma4:31b-mlx` |
| **`mitnick`** | **Kevin Mitnick** | **Adversarial QA & Honesty (`G4-Test`).** Defensive red-team mindset; owns fail-closed tests, `DEVICE_SMOKE`, and the Testing Jig. | Local Council | Local Ollama | **Local Family B** · `gemma4:31b-mlx` |
| **`jobs`** | **Steve Jobs** | **User Taste & Friction Auditor.** Sunlight readability, one primary action per screen, cuts jargon; briefs `dhh`. (Never `G5`). | Local Council | Local Ollama | Local Family A · `qwen3.8:27b-mlx` |
| **`scrum`** | **Scrum Master** | **Empirical Process Auditor.** Audits `SPRINT_DASHBOARD.md`, DoD compliance, and Testing Jig vs. Git. Never writes app code; never `G5`. | Local Council | Local Ollama | Local Family A · `qwen3.8:27b-mlx` |
| **`parent`** | **Orchestrator** | **Deterministic Router & Gatekeeper.** Compiles Rule 11 packets, applies local diffs, runs `G1` tests. Never ghostwrites a seat ballot. | Orchestrator | Host Session | Host session |
<!-- /seat-table:canonical -->

### Hard Independence Rules
1. **Cross-Family Review (`G5`):** Code written by Local Family A (`qweny`) **must** be peer-reviewed by Local Family B (`moxie`). Test code written by Local Family B (`mitnick`) **must** be peer-reviewed by Local Family A (`qweny`). Neither model family ever grades its own weights.
2. **Zero Alias Routing:** Every seat has one name and one runtime. Passing a Cloud seat name (`linus`, `dhh`, `carmack`, `knuth`) to `scripts/run_local_agent.sh` is rejected with exit code `2`.

---

## 3. Runtime Mechanism Glossary (Do Not Collapse)

| Mechanism | What Actually Runs | Can It Edit the Working Tree? | Valid Proof |
|---|---|---|---|
| **Cursor Cloud Task** (`environment: cloud`) | Independent Cloud VM on the seat's locked model family | Yes, on its cloud branch | `scripts/log_cloud_agent.sh` + cloud run ID |
| **`scripts/run_local_agent.sh <seat>`** | Local Ollama HTTP call (`qwen3.8:27b-mlx` or `gemma4:31b-mlx`) with auto-injected `01_` laws + `00_` contracts | **No.** Prints to `stdout`; `parent` applies the patch and runs `G1` | `.angie/local-agent-proof.log` (`packet_sha256`, `output_sha256`, `response_model`) |
| **Cursor Local Subagent** (`environment: local`) | Cursor subagent running on the **parent's cloud model** | Yes, directly in the working tree | **None.** Never counts as local Ollama tokens or `G0`/`G5` proof |
