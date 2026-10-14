# 00_ARCHITECTURE.md — ANGIE 2.0 System Architecture & Code-Owned Contracts

**Document Role:** Pure technical architecture, module boundaries, threading rules, and mathematical/ABI invariants for **ANGIE 2.0**.  
**Boundary:** Contains **zero** agent prompt laws (see [`01_OMARCHY_AGENT_PROMPTS.md`](01_OMARCHY_AGENT_PROMPTS.md)) and **zero** daily sprint/session state (see [`docs/SPRINT_DASHBOARD.md`](docs/SPRINT_DASHBOARD.md)). Auto-injected into every local coding and review run.

---

<!-- section:architecture-contracts -->
## 1. System Overview & Four-Layer Boundary

ANGIE 2.0 is a hands-free, chest- or head-mounted Android assistant (`com.angie.app`, Min SDK 29 / Target SDK 35, JDK 17, Kotlin + Jetpack Compose) paired with a phased edge/cloud active-learning pipeline:

1. **Layer 0 — Eyes (On-Device Vision + Depth + 3-Model Bake-Off):**
   - Wide camera `YUV_420_888` center-cropped to $160 \times 160$ RGB (`0` heap allocations per frame) → **1 active TFLite `Interpreter`** (`ssd_mv2_160_u8` | `yolox_nano_160_u8` | `effdet_lite0_160_u8`) + Camera2 `DEPTH16` millimeter range & flat-vs-3D variance ($\sigma < 30\text{ mm}$).
2. **Layer 1 — Spatial Memory (Indoor Magnetometer/Wi-Fi + Opt-In GPS):**
   - Indoor place tags (`magX, magY, magZ, |B|, headingDegrees` + top-8 Wi-Fi `BSSID → RSSI`), IMU dead-reckoning during ferromagnetic anomalies, goal aliases (`ice_cream → freezer`), and opt-in additive GPS geo-tags.
3. **Layer 2 — LLM Planner & Point-of-No-Return (PNR) Verifier:**
   - Consumes **only** active Layer 0 detections ($\ge 0.35$), Layer 1 place tags, and user STT transcripts. Never invents objects or container contents.
4. **Layer 3 — Server School (H0 GitHub Releases → H1 Nginx/Fybr → H3 MinIO + MQTT Verify):**
   - Battery-gated uploads → confidence-banded agent pre-labeling (`high` | `medium` | `verify`) → multi-human MQTT verification → retrain & SHA-locked release.

---

## 2. Package & Module Ownership Map

Every module separates **pure, 100% JVM-testable policy/math classes** ($\ge 85\%$ line coverage required) from thin Android OS/HAL wrappers:

| Module (`package`) | Pure JVM Policy / Math Classes | Android / HAL Glue Classes | Key Invariant |
|---|---|---|---|
| `ml` | `ModelLock`, `ModelContract`, `ModelSha`, `LabelSet`, `ModelKey`, `YuvCropConverter` | `MLInferenceEngine`, `ModelCatalog` | Single `Interpreter` in RAM; single-FD SHA-256 before `mmap`; zero per-frame allocations. |
| `camera` | *(Camera ranking / focal-length math)* | `CameraManagerService`, `DepthSensorController` | Wide-only default bind; `DEPTH16` opens 750 ms after RGB on dedicated `HandlerThread`. |
| `preview` | `Detection`, `DetectionParser`, `DepthAttacher`, `RecordBudgetMeter` | `TestPreviewScreen` | Floor `0.35`, sure $\ge 0.55$; flat if depth $\sigma < 30\text{ mm}$; honest 1 Hz record-budget meter. |
| `fusion` | `HeadingEstimator`, `HeadingState`, `SensorSnapshot` | `SensorFusionManager` | Baseline $45\,\mu\text{T}$, trusted $[25, 65]\,\mu\text{T}$; stationary spike triggers IMU yaw dead-reckoning; $15^\circ$ slew limit. |
| `kiosk` | `KioskPolicy`, `MountMode`, `VolumeChordTracker` | `KioskManager` | Runtime-only mount state; 3000 ms dual-volume chord + 200 ms poll fallback; `Inverted` = $180^\circ$ decor + pixel flip. |
| `feedback` | `SpeechScheduler`, `CuePatterns` | `AccessibilityFeedbackManager` | Hard $\le 3000\text{ ms}$ continuous speech cap ($80\text{ ms/char}$) + $400\text{ ms}$ mandatory silence; `Anomaly` flushes queue. |
| `places` | `PlaceTag`, `PlaceTagStore`, `PlaceJson`, `PlaceGuide`, `GoalAliasResolver`, `ContentsInspector`, `ClockFaceNarrator` | `WifiFingerprint` | Corrupt JSON fails closed to empty; arrival score $\le 6.0$; clock-face chunks $\le 36$ chars. |
| `voice` | `IntentRouter`, `UserIntent`, `QuerySession` | `VoiceIngress` | Deterministic regex routing; `pendingListen` across runtime mic permission prompt. |
| `capture` | `CaptureRetention` | `CaptureRecorder` | 1-slot `ArrayBlockingQueue` off analysis thread; $\le 240$ JPEG cap (legacy) + `filesDir/training/<sessionId>/` MP4+JSONL. |
| `sync` | `BatteryGate`, `PowerSnapshot` | `AngieWorkers`, `SyncStatusBus` | Upload requires `charging && battery >= 30% && unmetered`; NPU clustering requires `charging && battery >= 70%`. |
| `config` / `stream` / `ui` / `admin` | `StreamStatus` | `ConfigurationScreen`, `ConfigurationViewModel`, `AngieTheme`, `AngieDeviceAdminReceiver` | Only `remote_url` and `selected_model_id` persist in DataStore; sticky error reporting. |

---

## 3. Code-Owned Mathematical & ABI Contracts

| Domain | Invariant Contract |
|---|---|
| **Detector Tensor ABI (`ModelContract`)** | Exactly `1` input (`UINT8 [1,160,160,3]`, `76800 B`), `1` output (`FLOAT32 [1,64,6]` or `[64,6]`, `1536 B`, layout `ltrb_norm_conf_class`). Input `scale`/`zeroPoint` must match `models.lock` within `1e-6f`. Raw `UINT8` (`0.0 / 0`) is never affine-scaled. |
| **Model Load Path (`MLInferenceEngine`)** | Load **only** from `filesDir/models/<id>/model.tflite` + `labels.txt` on the single-thread analysis executor. Verify byte length + SHA-256 on the open `FileChannel` before `mmap`. Run 1 zeroed warmup probe before publishing `"model loaded, accelerator unverified"`. |
| **Compass vs. Anomaly (`HeadingEstimator`)** | Trigger `DeadReckoning` when $\omega < 0.2\text{ rad/s}$ and ($|B| > 100\,\mu\text{T}$ or $|B| < 15\,\mu\text{T}$ or $||B| - B_{\text{base}}| > 40\,\mu\text{T}$ or $|\dot{B}| > 80\,\mu\text{T/s}$). Resume compass after 15 consecutive samples in $[25, 65]\,\mu\text{T}$ with $\pm 15^\circ$ max step. |
| **DCMP Speech (`SpeechScheduler`)** | `MAX_CONTINUOUS_MS = 3000L`, `PAUSE_MS = 400L`, `MS_PER_CHAR = 80L`. `ObjectFound` (`[0,40,70,40]` ms) and `TargetLost` (`[0,400]` ms) use haptics + earcons only, never speech. |
| **Record-Budget Meter (`Layer 0`)** | `meter = min(storage_pct, battery_pct, thermal_pct, fps_pct)` sampled at 1 Hz. Tie-break: `thermal → storage → battery → fps`. At `0`, stop encoder, flush sidecar, close `Interpreter`, play stop earcon. |
<!-- /section:architecture-contracts -->
