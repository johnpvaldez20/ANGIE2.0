# ANGIE 2.0 — Master Product & Runtime Specification

**Document role:** Standalone, self-contained product and technical specification for **ANGIE 2.0**.  
**Independence:** Assume zero access to any prior repository, git history, or build artifacts. Every product requirement, layer boundary, mathematical formula, ABI contract, and on-device runtime behavior required to build and ship ANGIE 2.0 is defined in this document.

---

## 1. Product Vision & Non-Negotiable Honesty

### 1.1 One-liner
**A.N.G.I.E.** is a chest- or head-mounted Android phone assistant that watches a blind or low-vision wearer’s first-person scene, remembers indoor places without GPS, answers short voice queries, warns about critical physical anomalies, and supports a sighted/assisted **training and bake-off loop** (egocentric video + fused sensor/AI overlays + human label correction) — while staying **completely silent** in normal operation unless explicitly asked or warning of a critical state-change anomaly.

### 1.2 The Honesty Rule (Fail-Closed Contract)
ANGIE must **never** invent detections, places, container contents, hardware acceleration claims, or sync success:
- **Missing or rejected model** → sticky status (`model missing` or `model rejected: <reason>`), **zero boxes**, and spoken refusal on vision queries (`"model missing, I cannot check for <label>"`).
- **Out-of-vocabulary query** → if the loaded model’s `labels.txt` cannot express the queried noun, refuse (`"I can't detect <label>"`), never say `"I don't see <label>"`.
- **Missing depth sensor** → report `"depth camera missing"`, attach `depthMeters = null` and `flat = false` to detections; never fabricate `0.0m`.
- **Missing Wi-Fi scan / Location permission** → save place tag with magnetic/heading only and speak `"remembered <place> without wifi"`.
- **Accelerator reporting** → constructing an `NnApiDelegate` proves only that the delegate attached, **not** that the graph partitioned onto the NPU. Status copy must read `"model loaded, accelerator unverified"` until per-op partition and latency are measured on target hardware.
- **Unmeasured metrics** → any performance, thermal, battery, or test metric without a real hardware log or coverage counter must be marked `UNMEASURED`, never `0` or `100%`.

---

## 2. Personas & Mount Modes

### 2.1 Personas

| Persona | Primary Needs |
|---|---|
| **Blind / low-vision wearer** | Hands-free chest/head mount; voice + haptics + earcons only; zero touch reliance; DCMP-concise speech (≤ 3 s continuous); reliable escape back to normal phone use. |
| **Sighted caretaker / tester** | Handheld GUI; Live AI camera overlay with sure/unsure boxes; 3-model same-scene bake-off; post-session video review and label correction; URL and model setup. |
| **Dataset collector / trainer** | Voice-started or physical-button training capture while performing household micro-tasks; automatic background upload when charging on unmetered Wi-Fi. |

### 2.2 Physical Mount Modes (Kiosk State Machine)

Mount mode is **runtime-only** state (never persisted to disk; a process restart must always land in `Handheld` so a crash or reboot never traps the phone).

| Mode | Touchscreen | Screen Orientation | Window Rotation | Android Lock Task | Escape to Handheld |
|---|---|---|---|---|---|
| **Handheld** | Enabled | Unspecified (free) | `0°` | Off (`stopLockTask()`) | N/A |
| **Chest** | Disabled (`FLAG_NOT_TOUCHABLE`) | Forced `LANDSCAPE` | `0°` | On (`startLockTask()`) | Hold **both Volume Up + Volume Down ≥ 3000 ms** |
| **Helmet** | Disabled (`FLAG_NOT_TOUCHABLE`) | Unspecified | `0°` | On (`startLockTask()`) | Same 3 s volume chord |
| **Inverted** (upside-down head mount for eye-line camera) | Disabled (`FLAG_NOT_TOUCHABLE`) | Unspecified (do **not** use reverse portrait) | `decorView.rotation = 180f` (pivoted at `width/2, height/2` post-layout) + 180° in-place pixel rotation before ML/capture | On (`startLockTask()`) | Same 3 s volume chord |

**Key interception & Escape chord mechanics:**
- In locked modes (`Chest`, `Helmet`, `Inverted`), intercept and consume `KEYCODE_BACK`, `KEYCODE_HOME`, `KEYCODE_APP_SWITCH`, `KEYCODE_VOLUME_UP`, and `KEYCODE_VOLUME_DOWN` so single presses do not alter system volume or exit the app.
- When both volume keys are held down simultaneously, start a **200 ms main-thread polling timer** in addition to checking key-event timestamps. Many Android OEMs suppress `ACTION_DOWN` auto-repeat when both rockers are held; the 200 ms poll guarantees escape fires at `3000 ms` (`SystemClock.uptimeMillis()`).
- **Activity recreation safety:** Entering `Chest` forces a landscape configuration change that recreates the `Activity`. `KioskManager.reapply(activity)` must run in `onCreate` to immediately restore `FLAG_NOT_TOUCHABLE`, orientation, rotation, and lock task.
- **Lock authority:** Check `DevicePolicyManager.isDeviceOwnerApp(packageName)`. If Device Owner, register `setLockTaskPackages` and report `DeviceOwner` (true kiosk). Otherwise `startLockTask()` enters Android Screen Pinning and reports `ScreenPinning` (or `Failed` on `SecurityException`).
- **ADB emergency release:** `adb shell am task lock stop`.

---

## 3. Four-Layer System Architecture (How Everything Works Together)

ANGIE 2.0 separates perception, spatial memory, high-level planning, and crowd/cloud learning into four strict layers so that higher layers never hallucinate over empty lower layers:

```text
┌──────────────────────────────────────────────────────────────────────────┐
│ LAYER 3 — Server School (Cloud Queue + Agent Pre-Label + MQTT Consensus) │
│   Uploads (charging + Wi-Fi) → Object Store + DB → Agent bands →         │
│   MQTT multi-human verify → Retrain/Export → Immutable H0/H1 Release     │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │ HTTPS fetch + SHA-256 lock (`models.lock`)
                                ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ LAYER 0 — Eyes (On-Device Vision + Depth + Same-Scene 3-Model Bake-Off)  │
│   Wide CameraX YUV_420_888 → 160×160 RGB crop → 1 active TFLite model    │
│   (SSD-MV2 | YOLOX-Nano | EffDet-Lite0) + Camera2 DEPTH16 (mm + flat/3D) │
└───────────────┬───────────────────────────────────────┬──────────────────┘
                │ Detections (≥ 0.35 floor, ≥ 0.55 sure)│
                ▼                                       ▼
┌──────────────────────────────────────┐ ┌─────────────────────────────────┐
│ LAYER 1 — Spatial Memory (Indoor/GPS)│ │ Direct Reflex & Query Handlers  │
│   Mag XYZ + |B| + IMU Dead Reckoning │ │   • Inspect ("is there milk?")  │
│   + Wi-Fi RSSI (top 8) + opt-in GPS  │ │   • Clock-face plate narrator   │
│   + Goal aliases ("ice cream"→freezer│ │   • Haptic/earcon object cues   │
└───────────────┬──────────────────────┘ └──────────────┬──────────────────┘
                │ Place matches + bearings              │
                ▼                                       ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ LAYER 2 — LLM Planner & Micro-Task Verifier                              │
│   Consumes ONLY: (a) Layer 0 detections ≥ 0.35, (b) Layer 1 places,      │
│   (c) User STT transcript. Sequences multi-step goals ("I want ice       │
│   cream") & Point-of-No-Return (PNR) post-conditions. NEVER invents.     │
└───────────────────────────────┬──────────────────────────────────────────┘
                                │
                                ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ DCMP Speech Scheduler & Tactile Feedback                                 │
│   Anomaly (flushes + interrupts) vs Response (queued); ≤ 3.0 s speech    │
│   cap at 80 ms/char + 400 ms mandatory silence gap; haptics + earcons    │
└──────────────────────────────────────────────────────────────────────────┘
```

### 3.1 Languages & Stack Across Client, Host Tooling, and Cloud

| Tier | Language / Tech | Responsibility |
|---|---|---|
| **Mobile App (Phone Runtime)** | **Kotlin** (JDK 17, Android Min SDK 29 / Target 35, Jetpack Compose + Material 3, CameraX + Camera2, TensorFlow Lite + NNAPI, DataStore Preferences, WorkManager) | All on-device camera, depth, IMU/magnetic sensor fusion, TFLite inference, voice STT/TTS, kiosk lock, capture, and background sync. |
| **Model Export & Host Verification** | **Python 3.12** (TensorFlow 2.16, PyTorch, ONNX, TFLite converter) + **Bash** | Fusing detector graphs to the strict 1-in/1-out ABI, verifying tensor dumps, generating `models.lock` hashes, publishing releases, and running coverage reports. |
| **Sighted Caretaker Portal & Docs** | **HTML5 / CSS3 / Vanilla JS** | Static companion portal (`index.html`, `live-ai.html`, `train.html`) for sighted caretakers to learn HUD legends, mount setup, and training workflows; plus future web review UI. |
| **Cloud / Edge Services (Layer 3)** | **Docker + Nginx** (H1 static model & upload proxy behind NPMplus TLS/auth), **MinIO / S3** (H3 object store), **PostgreSQL/SQLite + MQTT broker** (crowd verify queue), **Python** (agent pre-labeling & retrain workers), optional **Rust** (high-throughput media ingest / sidecar validation / MQTT bridge services). | Hosting immutable detector releases, receiving battery-gated training uploads, running confidence-banded pre-labeling, and dispatching low-confidence frames to human verifiers. |

---

## 4. Phone Runtime Deep-Dive (Hardware, Sensors, Vision, Audio)

### 4.1 Target Hardware Profile
- **Minimum reference device:** Samsung Galaxy S21 Ultra (`SM-G998U1` or equivalent flagship; Snapdragon 888 / Exynos 2100 class, Android 10–15). Also compatible with Galaxy S20 Ultra (which includes a dedicated ToF `DEPTH16` sensor; S21 Ultra may report `depth camera missing` and degrade cleanly).

### 4.2 Camera & Depth Pipeline (`camera/`)
1. **Camera Selection (`CameraManagerService`):**
   - Query `ProcessCameraProvider.availableCameraInfos`.
   - Filter to `LENS_FACING_BACK` and **exclude** any camera advertising `REQUEST_AVAILABLE_CAPABILITIES_DEPTH_OUTPUT`.
   - Sort remaining back cameras by minimum `LENS_INFO_AVAILABLE_FOCAL_LENGTHS` ascending.
   - Select the **median focal length** camera (`ranked[ranked.size / 2]`) as the primary **Wide** camera.
   - **Default binding:** Bind **Wide-only** (`Preview` + `ImageAnalysis`) on a single-thread executor (`Executors.newSingleThreadExecutor()`). Ultrawide is not bound on the default path to avoid HAL concurrent-stream arbitration failures; report `"wide only: id=<id>"` (and `"Second camera not used on this build"` on the Live AI HUD).
   - `ImageAnalysis` configuration: `STRATEGY_KEEP_ONLY_LATEST`, `OUTPUT_IMAGE_FORMAT_YUV_420_888`.
2. **Delayed Depth Camera (`DepthSensorController`):**
   - Bypass CameraX. Scan `CameraManager.cameraIdList` for a camera with `REQUEST_AVAILABLE_CAPABILITIES_DEPTH_OUTPUT` and non-empty `ImageFormat.DEPTH16` output sizes.
   - Start **750 ms after** RGB camera start so concurrent open does not steal the wide session.
   - Choose the **smallest** `DEPTH16` resolution (`minByOrNull { width * height }`), open an `ImageReader` (`maxImages = 2`) on a dedicated `HandlerThread("angie-depth")`, and copy each frame into a single pre-allocated `ShortArray` under a lock.
3. **Zero-Allocation YUV-to-RGB Center Crop (`YuvCropConverter`):**
   - On every `ImageProxy`, center-crop the largest square `side = min(width, height)` and nearest-neighbor downsample into a reused `IntArray(160 * 160)` (`OUTPUT_SIZE = 160`).
   - BT.601 integer math:
     \[
     c = Y - 16,\quad d = U - 128,\quad e = V - 128
     \]
     \[
     R = \text{clamp}((298c + 409e + 128) \gg 8),\quad G = \text{clamp}((298c - 100d - 208e + 128) \gg 8),\quad B = \text{clamp}((298c + 516d + 128) \gg 8)
     \]
   - If `KioskManager.mode == MountMode.Inverted`, reverse the `IntArray(25600)` in-place (`rotate180`) **before** offering to capture or packing for TFLite.
   - Pack RGB bytes into a reused direct `ByteBuffer(160 * 160 * 3)` (`76,800` bytes) in `R, G, B` order. Zero heap allocations per frame.

### 4.3 Detector Lock, Strict ABI Gate, and Loader (`ml/`)

#### 4.3.1 `assets/models/models.lock` (Schema = 1)
Weights **never** live in git or APK assets. The APK bundles only `assets/models/models.lock` (`java.util.Properties` format):
```ini
schema=1
default=ssd_mv2_160_u8
order=ssd_mv2_160_u8,yolox_nano_160_u8,effdet_lite0_160_u8

<id>.display=Home basics (recommended)
<id>.optIn=false
<id>.url=https://.../model.tflite
<id>.sha256=<64 lowercase hex>
<id>.bytes=<exact byte length>
<id>.labels.sha256=<64 lowercase hex>
<id>.labels.count=<int>
<id>.in.shape=1,160,160,3
<id>.in.dtype=UINT8
<id>.in.scale=0.0
<id>.in.zeroPoint=0
<id>.out.dtype=FLOAT32
<id>.out.maxDetections=64
<id>.out.layout=ltrb_norm_conf_class
```
- **Installability rule:** An entry with a blank `url` or `sha256 == 0000...0000` (64 zeros) is `isInstallable = false` (`NOT_INSTALLABLE` in UI/scripts).
- **The three canonical Layer 0 slots:**
  1. `ssd_mv2_160_u8` — *"Home basics (recommended)"* (`optIn=false`, default).
  2. `yolox_nano_160_u8` — *"Light look"* (`optIn=false`).
  3. `effdet_lite0_160_u8` — *"Careful look (slower)"* (`optIn=true`).

#### 4.3.2 Strict Tensor ABI (`ModelContract`)
Every detector graph must absorb decoding and NMS inside the `.tflite` so that the runtime sees **one** uniform contract:

| Check | Required Value | Reject Status on Mismatch |
|---|---|---|
| Input / Output tensor count | `inputTensorCount == 1 && outputTensorCount == 1` | `model rejected: abi` (`bad io count`) |
| Input dtype | `UINT8` | `model rejected: abi` (`bad input type`) |
| Input shape | `[1, 160, 160, 3]` (NHWC; rejects NCHW `[1,3,160,160]`) | `model rejected: abi` (`bad input shape`) |
| Input byte size | `76800` (`160 * 160 * 3`) | `model rejected: abi` (`bad input bytes`) |
| Input quantization | `abs(input.scale - lock.in.scale) <= 1e-6f && input.zeroPoint == lock.in.zeroPoint` (Note: raw `UINT8` inputs with `0.0 / 0` must **not** be multiplied by scale) | `model rejected: abi` (`bad input quant`) |
| Output dtype | `FLOAT32` | `model rejected: abi` (`bad output type`) |
| Output layout | `ltrb_norm_conf_class` | `model rejected: abi` (`bad output layout`) |
| Output shape | `[1, 64, 6]` or `[64, 6]` (`AE_MAX_DETECTIONS = 64`; rejects `[1, 6, 64]`) | `model rejected: abi` (`bad output shape`) |
| Output byte size | `1536` (`64 * 6 * 4`) | `model rejected: abi` (`bad output bytes`) |

Each of the 64 output rows is 6 `FLOAT32` values:
\[
[\text{left}, \text{top}, \text{right}, \text{bottom}, \text{confidence}, \text{classId}]
\]
where coordinates are normalized in \([0, 1]\) on the upright \(160 \times 160\) square, and unused rows are padded with `confidence = 0.0f`.

#### 4.3.3 TOCTOU-Safe Verification & Single-Interpreter Lifecycle (`MLInferenceEngine`)
All model loads (`reloadModel`) and closes (`close`) execute **exclusively on the camera analysis single-thread executor**:
1. **Always tear down first:** `clearSession()` closes any active `Interpreter`, closes `NnApiDelegate`, closes the open `FileInputStream`, clears `MappedByteBuffer`, and publishes `emptyList()` detections (no "last-good model" kept on failure).
2. **No silent fallback:** Empty, unknown, or legacy stored model keys resolve to `null` → publish `"model missing"`, zero boxes.
3. **Single-FD SHA-256 + mmap (No TOCTOU):** Open `FileInputStream(filesDir/models/<id>/model.tflite)`, verify `channel.size() == entry.bytes`, stream SHA-256 over the same `FileChannel` from position 0, verify `digest == entry.sha256`, then `channel.map(READ_ONLY, 0, size)` while keeping `FileInputStream` open for the life of the mapping.
4. **Verified Label Sidecar (`LabelSet`):** Read `filesDir/models/<id>/labels.txt` into memory once, verify SHA-256 against `entry.labelsSha256`, parse non-empty trimmed UTF-8 lines, verify `lines.size == entry.labelsCount`, and reject duplicate labels.
5. **Delegate + ABI + Zeros Probe:** Construct `NnApiDelegate()`, construct `Interpreter(buffer, Options().addDelegate(nnapi))`, validate `ModelContract`, and execute one warmup/probe `session.run(probeIn, probeOut)` with zeroed direct buffers (`76,800 B` → `1,536 B`). If the probe throws, close and publish `"model rejected: probe"`.
6. **Success state:** Publish `"model loaded, accelerator unverified"`.

#### 4.3.4 Confidence Bands & Depth Attachment (`preview/`)
- **Confidence thresholds (`DetectionParser`):**
  - Drop any row with `confidence < 0.35f` (`MIN_CONFIDENCE`) or `classId` out of bounds of `LabelSet` (never emit `"Unknown"`).
  - **Unsure band:** `0.35f <= confidence < 0.55f` → drawn with a **dashed stroke** (`PathEffect.dashPathEffect(floatArrayOf(12f, 8f), 0f)`) and a trailing `?` in the Live AI overlay caption.
  - **Sure band:** `confidence >= 0.55f` (`SURE_CONFIDENCE`) → drawn with a **solid stroke**.
- **3D vs Flat 2D Artifact Rejection (`DepthAttacher`):**
  - Each `DEPTH16` pixel stores range in millimeters in the lower 13 bits: `mm = sample and 0x1FFF` (ignore `0` samples).
  - Project the normalized bounding box `[left, top, right, bottom]` onto the depth frame dimensions.
  - Compute mean distance \(\mu\) (converted to meters: \(\mu / 1000\)) and standard deviation \(\sigma\) in millimeters across valid pixels inside the box:
    \[
    \sigma = \sqrt{\frac{1}{N}\sum_{i=1}^{N} (d_i - \mu)^2}
    \]
  - **Flat vs Physical rule:** If \(\sigma < 30.0\text{ mm}\) (`FLAT_STDDEV_MM`), classify the detection as `flat = true` (e.g., an object on a TV screen or printed wallpaper); otherwise `flat = false` (physical 3D object).

### 4.4 Sensor Fusion: Compass vs Metallic Infrastructure (`fusion/`)
- **Sensors:** `Sensor.TYPE_MAGNETIC_FIELD`, `Sensor.TYPE_ACCELEROMETER`, `Sensor.TYPE_GYROSCOPE` registered at `SENSOR_DELAY_GAME`.
- **Conflict:** Elevators, trains, and steel doors warp the magnetic field (\(|B| = \sqrt{B_x^2 + B_y^2 + B_z^2}\)), causing compass azimuth to swing wildly by 45°–180°.
- **Mathematical contract (`HeadingEstimator`):**
  - Nominal Earth field band: \(25.0\,\mu\text{T} \le |B| \le 65.0\,\mu\text{T}\).
  - Ambient baseline \(B_{\text{base}}\) initializes at \(45.0\,\mu\text{T}\) and updates via exponential moving average (\(\alpha = 0.05\)) **only** while in `Compass` mode and \(|B| \in [25, 65]\,\mu\text{T}\):
    \[
    B_{\text{base}} \leftarrow B_{\text{base}} + 0.05(|B| - B_{\text{base}})
    \]
  - Gyroscope angular speed magnitude: \(\omega = \sqrt{\omega_x^2 + \omega_y^2 + \omega_z^2}\). Physical rotation is active when \(\omega \ge 0.2\text{ rad/s}\).
  - **Magnetic anomaly trigger:** Fires when the user is **not rotating** (\(\omega < 0.2\text{ rad/s}\)) and any of the following hold:
    1. Spike: \(|B| > 100.0\,\mu\text{T}\)
    2. Shielding drop: \(|B| < 15.0\,\mu\text{T}\)
    3. Baseline deviation: \(||B| - B_{\text{base}}| > 40.0\,\mu\text{T}\)
    4. Rate of change: \(|\Delta |B| / \Delta t| > 80.0\,\mu\text{T/s}\)
  - **Dead-Reckoning integration:** While in `DeadReckoning`, ignore the magnetometer and integrate gyroscope yaw projected onto the gravity vector \(\mathbf{a}\):
    \[
    \dot{\psi} = \frac{\boldsymbol{\omega} \cdot \mathbf{a}}{\|\mathbf{a}\|},\quad \theta \leftarrow (\theta + \text{deg}(\dot{\psi})\Delta t) \bmod 360^\circ
    \]
  - **Recovery & Slew limiter:** Return to `Compass` mode only after **15 consecutive samples** inside \([25, 65]\,\mu\text{T}\). Clamp the first resumed compass step to at most **\(\pm 15.0^\circ\)** (`HEADING_SLEW_DEGREES`) so heading never snaps.

### 4.5 Audio, Voice Ingress, and DCMP Speech Scheduler (`feedback/`, `voice/`)
- **Strict DCMP Brevity (`SpeechScheduler`):**
  - Continuous speech is hard-capped at **`MAX_CONTINUOUS_MS = 3000L` (3.0 s)**, estimated at **`MS_PER_CHAR = 80L`** (~37 characters max per continuous run). Strings exceeding remaining budget are truncated at the last word boundary \(\ge 8\) chars.
  - After reaching the 3.0 s cap, enforce a mandatory **`PAUSE_MS = 400L` (400 ms)** silence window before any further speech.
  - **Priorities:**
    - `SpeechPriority.Anomaly`: Clears the entire pending queue, truncates any active utterance immediately (`TextToSpeech.QUEUE_FLUSH`), and speaks the anomaly now.
    - `SpeechPriority.Response`: Queues in FIFO order (`TextToSpeech.QUEUE_ADD`) and drains across 400 ms pauses.
- **Non-Verbal Cues (`CuePatterns`):**
  - Routine detection transitions **never speak words**:
    - `ObjectFound` (0 → ≥1 detections): Vibration waveform `[0, 40, 70, 40]` ms (double pulse) + two `TONE_PROP_BEEP` earcons (40 ms at 0 ms and 110 ms) on `STREAM_MUSIC`.
    - `TargetLost` (≥1 → 0 detections): Vibration `[0, 400]` ms + one `TONE_CDMA_LOW_L` earcon (180 ms).
- **Voice Ingress (`VoiceIngress`):** On-device `SpeechRecognizer` (`ACTION_RECOGNIZE_SPEECH`, `LANGUAGE_MODEL_FREE_FORM`) on the main thread. If `RECORD_AUDIO` is not yet granted when the user taps Listen, request permission and set `pendingListen = true` (do not sticky-fail before the user responds to the prompt).

---

## 5. Complete Use-Case Specifications (UC-01 through UC-13)

### UC-01 — Wearable Session Without Trapping the Phone
- **Behavior:** Selecting `Chest`, `Helmet`, or `Inverted` locks touch, pins the task, and orients the display/frame. Holding both volume keys for 3.0 s returns to `Handheld` within ≤ 5 s without ADB. `FLAG_KEEP_SCREEN_ON` prevents screen-timeout camera teardown while the Activity is visible.
- **Future extension:** Foreground service / partial wake lock so backgrounding or screen-off on silent chest recordings does not stop camera/sensor streams.

### UC-02 — Quick Stills Capture (Legacy Low-Bandwidth Path)
- **Behavior:** Handheld-only button labeled `"Quick stills (not training)"`. Captures the upright \(160 \times 160\) inference crop at **500 ms minimum interval (~2 FPS)**, encoded as JPEG (quality `80`) on a background daemon thread (`angie-capture`) via a 1-slot `ArrayBlockingQueue`.
- **Storage & Retention:** Writes `<epochMs>.jpg` to `filesDir/captures/`. `CaptureRetention.prune` deletes oldest files whenever count exceeds **240** (~2 minutes of stills). Works even when the model is missing. Retired once UC-13 video training is smoked on hardware.

### UC-03 — Battery-Gated Background Sync & Preprocessing (`sync/`)
- **DataSync gate (`BatteryGate`):** WorkManager `DataSyncWorker` runs **only** when `charging == true && batteryPercent >= 30 && unmeteredWifi == true`.
  - Reads `remote_url` from DataStore Preferences (must be `http://` or `https://`).
  - Uploads each capture via HTTP `POST` (`Content-Type: image/jpeg` or bundle). On HTTP `200..299`, deletes the local file; on non-2xx or IO error, retains the file and returns `Result.retry()`.
- **Offline NPU Clustering gate:** `OfflinePreprocessingWorker` runs **only** when `charging == true && batteryPercent >= 70`. Scans buffered recordings to cluster low-confidence / unknown object crops so novel classes can be queued for labeling without uploading raw multi-gigabyte video.

### UC-04 — Remember a Place at Home (Indoor, No GPS Required)
- **Voice triggers (`IntentRouter`):**
  - `"remember this as (the) <name>"`
  - `"tag this as (the) <name>"`
  - `"drop a tag for|as (the) <name>"`
- **Fingerprint capture (`PlaceTagStore`):**
  - Captures current `magX`, `magY`, `magZ`, `magMagnitude`, `headingDegrees`, and up to **8 Wi-Fi BSSID → RSSI** pairs from `WifiManager.scanResults` (requires `ACCESS_FINE_LOCATION`).
  - Overwrites any existing tag with the same case-insensitive `spokenName` and persists to `filesDir/places/places.json` (corrupt JSON fails closed to an empty list).
  - Speaks `"remembered <name>"` or `"remembered <name> without wifi"` if Wi-Fi scan was empty or lacked permission.

### UC-05 — Find a Remembered Place & Goal Alias Resolution
- **Voice triggers:** `"i want (some|a) <goal>"`, `"find <goal>"`, `"where is <goal>"`, `"take me to <goal>"`, `"get (me) <goal>"`.
- **Alias resolution (`GoalAliasResolver`):** Maps user goals to place names via `filesDir/places/aliases.json` with built-in defaults:
  - `ice_cream`, `icecream`, `frozen_dessert` → `"freezer"`
  - `milk`, `refrigerator` → `"fridge"`
- **Matching distance score (`PlaceTagStore.score` — lower is closer):**
  \[
  d_{\text{mag}} = \sqrt{(B_x - B_{x,\text{tag}})^2 + (B_y - B_{y,\text{tag}})^2 + (B_z - B_{z,\text{tag}})^2}
  \]
  \[
  \Delta |B| = ||B| - |B|_{\text{tag}}|,\quad \Delta \theta = \frac{\min(|\theta - \theta_{\text{tag}}| \bmod 360^\circ,\; 360^\circ - (|\theta - \theta_{\text{tag}}| \bmod 360^\circ))}{180^\circ}
  \]
  \[
  d_{\text{wifi}} = \begin{cases} 0 & \text{if either scan is empty} \\ 4.0 & \text{if BSSID intersection is empty} \\ \frac{1}{20 \cdot |K|}\sum_{k \in K} |\text{RSSI}_k - \text{RSSI}_{k,\text{tag}}| & \text{otherwise} \end{cases}
  \]
  \[
  \text{score} = d_{\text{mag}} + 0.25\,\Delta |B| + 8.0\,\Delta \theta + d_{\text{wifi}}
  \]
- **Guidance loop (`QuerySession` + `PlaceGuide`):**
  - Polls every **2000 ms**. Speaks **only when the phrase changes** (no continuous chatter).
  - Signed heading delta \(\delta \in (-180^\circ, 180^\circ]\):
    - \(|\delta| < 20^\circ\) → `"<place> is ahead"`
    - \(\delta \in [20^\circ, 90^\circ]\) → `"<place> is ahead and a little right"`
    - \(\delta \in [-90^\circ, -20^\circ]\) → `"<place> is ahead and a little left"`
    - \(\delta > 90^\circ\) → `"<place> is to your right"`
    - \(\delta < -90^\circ\) → `"<place> is to your left"`
  - **Arrival:** When `match.tag.id == targetTag.id && score <= 6.0f` (`ARRIVED_SCORE`), speak `"you are at the <place>"`, stop guidance, and if the original goal was an alias (e.g., `"ice_cream"` at `"freezer"`), automatically chain into **UC-06** `inspect("ice_cream")`.

### UC-06 — Inspect Contents (“Is there milk?”)
- **Voice triggers:** `"is there <label> (in there|it|here)?"`, `"do i|you see <label>?"`, `"look for <label>"`, `"check (for) <label>"`.
- **Logic (`ContentsInspector`):**
  1. If `!modelAvailable` → `"model missing, I cannot check for <want>"`.
  2. If `!LabelSet.canExpress(want)` (neither substring matches any class in `labels.txt`) → `"I can't detect <want>"`.
  3. If any current detection has `confidence >= 0.35f` and normalized label matching `want` → `"yes, <want>"`; else `"I don't see <want>"`.

### UC-07 — Clock-Face Plate Description
- **Voice triggers:** `"what's on my plate?"`, `"describe (my) plate"`, `"plate check"`.
- **Logic (`ClockFaceNarrator`):**
  1. If `!modelAvailable` → `"model missing, I cannot describe the plate"`.
  2. Filter detections where `label != "plate"`. If empty → `"I don't see food on the plate yet"`.
  3. Center of clock \((o_x, o_y)\) is the center of the first `"plate"` detection box, or \((0.5, 0.5)\) if no plate box is present.
  4. For each food box center \((c_x, c_y)\), compute angle with \(12\text{ o'clock} = \text{up}\) (invert image Y):
     \[
     \text{deg} = \left(\text{atan2}(c_x - o_x,\; -(c_y - o_y)) \cdot \frac{180}{\pi} + 360\right) \bmod 360,\quad \text{hour} = \left\lfloor\frac{\text{deg}}{30}\right\rceil \bmod 12 \;\; (0 \mapsto 12)
     \]
  5. Sort items by hour, format `"<label> at <hour> o'clock"`, and pack into \(\le 36\)-character speech chunks (`". "` separated) so every chunk fits the 3.0 s speech budget.

### UC-08 — Sighted Live AI View & Depth Flat/Physical Overlay
- **UI (`TestPreviewScreen`):** Full-screen wide camera `PreviewView` (`FILL_CENTER`, `COMPATIBLE`) with dark scrim (`#D90A0A0A`), high-contrast white/yellow typography (`#FFFFFF` / `#FFEB3B` for sunlight readability), one-line warning banner when model is missing/rejected or camera degraded, and glanceable HUD lines below.
- **Box rendering:** Solid stroke (`≥ 0.55`), dashed stroke + `?` (`0.35–0.55`), caption with `<label> <confidence> · <depth>m flat|3D`.
- **Navigation:** Single prominent `"Back to setup"` button returns to Configuration.

### UC-09 — Magnetic Anomaly vs Heading
- See §4.4 for the exact state machine and formulas.

### UC-10 — Anomaly Speech & DCMP Brevity
- See §4.5 for priority queue, interruption, haptics, earcons, and the 3.0 s / 400 ms law.

### UC-11 — Household Micro-Task Verification (Point-of-No-Return / PNR)
- **Goal:** Verify whether daily micro-tasks succeeded or caused an anomaly (e.g., scraping food into trash vs dropping on floor/clogging sink; washing dishes vs water splashing across a non-porous counter; rain on window vs floor spill).
- **Temporal taxonomy:**
  1. **Pre-condition:** Initial spatial state (e.g., plate with scraps over counter; dry countertop).
  2. **Point of No Return (PNR):** The frame where state change becomes inevitable (hand tilts plate; sponge presses under running faucet).
  3. **Post-condition:** Final spatial state verified via object + surface + depth variance + temporal background subtraction (e.g., scraps inside trash receptacle = silent pass; scraps on floor or water scatter on flat counter = immediate `SpeechPriority.Anomaly` warning: `"Warning: Water spilling on floor"`).

### UC-12 — Trade Modules & Quality-Assurance Documentation (Future)
- Domain-specific pluggable detector + checklist packs (plumbing, electrical, automotive) using the same `models.lock` slot and voice `"document this"` capture + summary upload.

### UC-13 — Voice-Started Training Mode (Record → Overlay → Sighted Correction)
- **Wake & Voice Intents:**
  - Two-word wake phrase: **`"Hey ANGIE"`** (arms listening in any mount mode).
  - Start: `"start training"`, `"start training mode"`, `"begin training"` → TTS `"training started"`. Idempotent if already training.
  - Stop: `"stop training"`, `"end training"`, `"end training mode"` (or holding the 3 s volume escape chord) → flushes/finalizes files, TTS `"training stopped"`.
- **Capture Format & Storage:**
  - Stored under `filesDir/training/<sessionId>/` (separate from `filesDir/captures/`).
  - **Video:** Wide camera MP4 at **1080p @ 30 FPS** target (15 FPS thermal floor) using hybrid binding: try CameraX `VideoCapture + Preview + ImageAnalysis` on wide first; on bind failure, record sticky reason and fall back to Camera2 `MediaRecorder`. Never stitch JPEGs into fake video.
  - **Lossless Sidecar (`session.jsonl`):** Clean camera pixels in MP4 + time-aligned JSONL rows containing: monotonic timestamp, mount mode, heading, `|B|` + baseline + dead-reckoning state, depth summary, and per-detection `[label, rawConfidence, certaintyBand (sure|unsure|unknown), normalizedBox, depthMeters, flat]`.
- **Sighted Review & Label Correction UI (Handheld only):**
  - Scrub/play recorded session with sidecar overlays rendered live (unsure `0.35–0.55` boxes highlighted dashed + `?`).
  - Sighted user taps an existing box or draws a new box over a missed object, and picks a class, types a **new class name**, or marks `not an object / ignore`.
  - **Append-only ground truth:** Store both the original AI hypothesis (`label, confidence`) and the human correction (`correctedLabel, reviewerId, timestamp, frameRange`) — never overwrite the AI’s original prediction.
  - Finalized sessions upload via `BatteryGate` (charging + ≥ 30% + unmetered Wi-Fi); never upload while actively recording.

---

## 6. Layer 0 Extension: Same-Scene 3-Model Bake-Off & Record-Budget Meter

### 6.1 Three Files on Disk, One Interpreter in RAM
- All three detectors (`ssd_mv2_160_u8`, `yolox_nano_160_u8`, `effdet_lite0_160_u8`) are prefetched into `filesDir/models/<id>/` and SHA-verified before a bake-off walk starts.
- Only **one** `Interpreter` and **one** `NnApiDelegate` may be resident in RAM at any instant.
- **Strict reload sequence between models:**
  1. Stop `run` and drain in-flight `ImageProxy`.
  2. `Interpreter.close()` + `delegate.close()` + unmap previous file (never overlap two mmaps).
  3. Stream SHA-256 of the next model, mmap, validate `ModelContract`, run 1 zeroed warmup `run` (triggers NNAPI compile), and log `sha_ms`, `map_ms`, `warmup_ms`, and dropped frames.
- **Thermal soak gate between clips:** Do not load the next model until `PowerManager` thermal status has remained `NONE` or `LIGHT` continuously for `SOAK_HOLD_S` (default `60 s`, max wait `SOAK_MAX_S = 300 s`, else abort with `"soak failed"`). Rotate model order across sessions (`A→B→C`, `B→C→A`, `C→A→B`).

### 6.2 Sighted Bake-Off Walk Flow
1. Pick model 1 of 3 → tap **Test model** → full-screen video with boxes, corner detection score (`objects in view vs identified`), and the **0–100% `record budget` meter**.
2. Walk the scene (e.g., kitchen) → tap **Save** → view summary (`# detected`, `# identified`).
3. Prompt: **"Ready to test next model?"**
   - **Yes** → thermal soak → load next model under the **same activity name** → repeat walk.
   - **No / Exit** → persist locally. If fewer than 3 models were tested, prompt to **name the activity** and create a per-user, on-device **`ResumeQueueItem(activityId, remainingModelLockIds[])`** so the user can finish the remaining models later.

### 6.3 Physical-Button Silent Record (Chest / Helmet)
- Triggered by a debounced (`≥ 400 ms`) hardware action distinct from the 3 s volume escape chord (and ignored while the escape chord timer is active).
- **Zero Preview Surfaces:** Binds **only** wide `ImageAnalysis` + video encoder + JSONL sidecar writer. Do **not** bind CameraX `Preview`, `PreviewView`, `1×1` dummy surfaces, or `FLAG_KEEP_SCREEN_ON`. Saves ~25 MB of GPU/gralloc preview buffer queues and allows recording with the screen off.
- **Audio feedback:** Plays a distinct **start earcon** on `STREAM_MUSIC` when recording starts, and a **stop earcon** on stop, escape chord, or meter-zero (no TTS). Produces entries in an **unnamed video queue** on the main menu.

### 6.4 Record-Budget Meter (0–100%) Mathematical Contract
Sampled at **1 Hz** off the analysis thread. Displays `record budget <meter>% · <binding>` (where `binding` is `thermal`, `storage`, `battery`, or `fps`). **Never** call this a "context window", "token budget", or "NPU %". If any session-header parameter is missing, meter = `0` (`record budget unconfigured`, fail closed).

**Default session header constants:**
- `SESSION_BUDGET_S = 300` (5 min planned clip)
- `STORAGE_RESERVE_B = 536_870_912` (512 MiB)
- `STORAGE_PRIOR_BPS = 2_097_152` (2 MiB/s prior for first `STORAGE_WINDOW_S = 5 s`)
- `BATTERY_FLOOR_PCT = 15` (stop recording at 15%; upload gate remains 30%)
- `BATTERY_PRIOR_PCT_PER_MIN = 1.0`
- `THERMAL_MODERATE_PCT = 40`
- `FPS_WINDOW_S = 5`, `PLANNED_ENC_HZ = 15`, `PLANNED_RUN_HZ = 15`, `FPS_FLOOR_RATIO = 0.5`, `FPS_FLOOR_WINDOWS = 2`

**Four terms (`clamp(x) = min(100, max(0, x))`):**
1. **Storage:**
   \[
   \text{free\_b} = \max(0,\; \text{available\_bytes} - \text{STORAGE\_RESERVE\_B}),\quad \text{bps} = \begin{cases} \text{bytes\_written} / \text{elapsed\_s} & \text{if } \text{elapsed\_s} \ge 5 \\ \text{STORAGE\_PRIOR\_BPS} & \text{otherwise} \end{cases}
   \]
   \[
   \text{storage\_pct} = \text{clamp}\!\left(100 \cdot \frac{\text{free\_b} / \text{bps}}{\text{SESSION\_BUDGET\_S}}\right)
   \]
2. **Battery:**
   \[
   t_{\text{bat}} = \begin{cases} +\infty & \text{if slope\_known and slope} \ge 0 \\ \max(0, \text{pct} - 15) / |\text{slope}| & \text{if slope\_known and slope} < 0 \\ \max(0, \text{pct} - 15) / (1.0 / 60) & \text{otherwise} \end{cases}
   \]
   \[
   \text{battery\_pct} = \text{clamp}\!\left(100 \cdot \frac{t_{\text{bat}}}{\text{SESSION\_BUDGET\_S}}\right)
   \]
3. **Thermal (`PowerManager` thermal status):**
   - `NONE` or `LIGHT` → `100`
   - `MODERATE` → `40` (`THERMAL_MODERATE_PCT`)
   - `SEVERE`, `CRITICAL`, `EMERGENCY`, `SHUTDOWN`, or unreadable → `0`
4. **FPS (both encoder and TFLite `run` must hold):**
   \[
   \text{enc\_pct} = \text{clamp}\!\left(100 \cdot \frac{\text{enc\_frames} / 5}{15}\right),\quad \text{run\_pct} = \text{clamp}\!\left(100 \cdot \frac{\text{run\_count} / 5}{15}\right),\quad \text{fps\_pct} = \min(\text{enc\_pct}, \text{run\_pct})
   \]
   If `enc_fps < 7.5` or `run_fps < 7.5` for 2 consecutive windows → `fps_pct = 0` (`recording invalid: fps`).
5. **Combined meter & zero action:**
   \[
   \text{meter} = \min(\text{storage\_pct}, \text{battery\_pct}, \text{thermal\_pct}, \text{fps\_pct})
   \]
   Tie-break order for `binding`: `thermal` → `storage` → `battery` → `fps`. When `meter == 0`, immediately stop encoder, flush sidecar, close `Interpreter`, play stop earcon, and post `"record budget 0: <binding>"`.

---

## 7. Layer 1, Layer 2, and Layer 3 Future Specifications

### 7.1 Layer 1 Extension — Opt-In GPS Geo Tags
- Indoor magnetic + heading + Wi-Fi fingerprint (`UC-04`/`UC-05`) remains the primary home-place mechanism.
- **Additive GPS:** Opt-in (default **off**). When enabled, attaches `[latitude, longitude, horizontalAccuracyMeters, timestampMs]` to `PlaceTag` for outdoor and cross-building recall (e.g., transit entrances, tactile paving QR waypoints).
- **Honesty:** Never claim indoor room-level arrival from GPS alone; if GPS is stale or denied, fall back to magnetic/Wi-Fi or report unavailable. Encrypt stored location tags at rest and allow per-tag deletion.

### 7.2 Layer 2 — LLM Planner (`uc-llm-guide`)
- **Purpose:** Turn high-level goals (`"I want ice cream"`) into step-by-step spoken navigation and manipulation hints (`"freezer is ahead" → "reach for left handle" → "pint on top shelf"`).
- **Strict Input Firewall:** The planner may consume **only**:
  1. Active Layer 0 detections with `confidence >= 0.35f` (distinguishing `sure >= 0.55f` from `unsure`).
  2. Layer 1 `PlaceTag` records and `GoalAliasResolver` mappings.
  3. The user’s on-device STT transcript.
- **Forbidden behaviors (must fail acceptance tests if violated):**
  - Never assert an object is inside a container unless Layer 0 detected that class after the container opened.
  - If open freezer detections show only `broccoli` and `carrot`, say `"I don't see ice cream; I see vegetables"` — never guess `"maybe a pint behind them"`.
  - If the detector is missing/rejected or the LLM times out, fail closed with a short DCMP phrase (`≤ 3.0 s`).

### 7.3 Layer 3 — Server School, Crowd MQTT Verification, and Hosting Roadmap

#### 7.3.1 Phased Hosting Architecture
| Phase | Target | Stack & Auth | Purpose |
|---|---|---|---|
| **H0 (Bootstrap)** | Immutable GitHub Releases | Public/authenticated Release assets pinned by versioned tag (`detector-<id>-v1/{model.tflite,labels.txt}`). Never use floating `latest` URLs. | Initial weight distribution + host SHA-256 verification. |
| **H1 (Beta)** | `https://angie.fybr-labs.com` | Docker `nginx:alpine` (with `gzip off` for byte-identical `.tflite` delivery) + upload/queue API behind **NPMplus** TLS & auth. | Beta weight hosting + receiving battery-gated training bundles. |
| **H3 (Scale)** | S3-compatible Object Store | **MinIO** behind NPMplus + worker queue + MQTT broker. | High-volume egocentric video/sidecar storage and active-learning retrain loop. |

**Immutability invariant:** A published `(model_id, version_tag)` tuple freezes `[model_url, model_sha256, model_bytes, labels_url, labels_sha256, labels_count]`. Changing a single byte requires a new version tag (`v2`, `v3`) and a `models.lock` update.

#### 7.3.2 Active-Learning & MQTT Multi-Human Verify Loop
1. **Consent & Privacy Gate:** No egocentric video or images leave the phone without explicit user opt-in, configured retention window (e.g., 30-day auto-delete), and face/screen/document redaction policy. Server-suggested activity names are returned **only** to the uploading user.
2. **Agent Pre-Labeling Bands (No Fake "99%" Claims):**
   - Server vision/LLM workers propose bounding boxes and labels on uploaded frames and assign a calibrated band:
     - `high` — calibrated on held-out validation set (`"Likely: <label>"`).
     - `medium` — uncalibrated proposal (`"Maybe: <label> — needs verify"`).
     - `verify` — below confidence bar; **never** auto-exported to training sets.
3. **MQTT Crowd Verification:**
   - Frames in the `verify` band publish to an MQTT job topic (`angie/verify/<jobId>`).
   - Volunteer sighted users in the training portal/app receive the cropped frame + context, and type or select the label.
   - Once **multi-human consensus** (e.g., 2-of-3 or 3-of-5 agreement) is reached, the verified ground-truth row commits to the training dataset.
4. **Closing the Loop to the Phone’s Eyes:**
   - Retraining exports a new fused `[1,160,160,3] UINT8 → [1,64,6] FLOAT32` `.tflite` and `labels.txt`, verifies the ABI dump, publishes `detector-<id>-vN`, and updates `models.lock` so phones fetch and verify the upgraded weights.

---

## 8. Permissions, Persistence, and Quality Verification

### 8.1 Android Permissions
| Permission | Purpose | Degradation if Denied |
|---|---|---|
| `CAMERA` | Wide RGB analysis/preview + Camera2 `DEPTH16` | `"camera permission denied"`, `"depth stopped"` |
| `RECORD_AUDIO` | On-device `SpeechRecognizer` voice queries | `"voice mic denied"` |
| `ACCESS_FINE_LOCATION` + `ACCESS_WIFI_STATE` | Wi-Fi BSSID/RSSI indoor place fingerprinting (+ future opt-in GPS) | Places save mag/heading only; speaks `"without wifi"` |
| `INTERNET` + `ACCESS_NETWORK_STATE` | Battery-gated capture sync (`DataSyncWorker`) | Uploads stay queued locally |
| `VIBRATE` | Haptic pulses (`ObjectFound`, `TargetLost`) | Audio earcons + TTS still function |
| `BIND_DEVICE_ADMIN` (Device Owner) | True `LockAuthority.DeviceOwner` kiosk pinning | Falls back to `ScreenPinning` |

### 8.2 On-Device Storage Layout
- **DataStore Preferences (`settings`):**
  - `remote_url: String` (default `""`; validated for `http://` or `https://`).
  - `selected_model_id: String` (lock id or `__none__`; normalized on cold start, never auto-loads an unrequested default).
- **Internal Files (`context.filesDir`):**
  - `filesDir/models/<id>/model.tflite` & `labels.txt` — SHA-verified detector weights and class names.
  - `filesDir/places/places.json` — saved `PlaceTag` array.
  - `filesDir/places/aliases.json` — goal-to-place map (`ice_cream -> freezer`, etc.).
  - `filesDir/captures/<epochMs>.jpg` — legacy 160×160 quick stills (capped at 240 files).
  - `filesDir/training/<sessionId>/` — UC-13 / Layer 0 bake-off MP4 video + `session.jsonl` sidecar + human label corrections.

### 8.3 Verification & Testing Jig Requirements
ANGIE 2.0 must maintain an automated host **Testing Jig** (`./gradlew :app:testingJig`) that gates every build and release:
1. **Pure JVM Unit Suite (100% deterministic, no hardware required):**
   - `ModelLock` parser (schema, hex64, duplicate IDs, installability).
   - `ModelContract` ABI gate (all 9 reject reasons including NCHW transpose tricks and quant mismatches).
   - `MLInferenceEngine` loader (missing file, corrupt SHA, bad labels, TOCTOU single-FD mmap, session clear on failure).
   - `YuvCropConverter` (BT.601 math, zero-allocation reuse, 180° inverted rotation).
   - `DepthAttacher` (13-bit millimeter extraction, \(\sigma < 30\text{ mm}\) flat vs physical classification).
   - `HeadingEstimator` (stationary magnetic spike/drop/rate triggers dead reckoning; real gyro rotation \(\ge 0.2\text{ rad/s}\) does not false-trigger; 15-sample recovery; \(15^\circ\) slew limit).
   - `SpeechScheduler` (3.0 s continuous cap, 400 ms pause, `Anomaly` flush/interruption).
   - `PlaceTagStore`, `PlaceGuide`, `GoalAliasResolver`, `ContentsInspector`, `ClockFaceNarrator`, `IntentRouter`.
   - `KioskPolicy` & `VolumeChordTracker` (3.0 s chord, 200 ms poll fallback, key consumption, Chest landscape, Inverted 180°).
   - `BatteryGate` (29%/30%/69%/70% thresholds across charging and metered/unmetered states).
2. **Automated Coverage & Use-Case Linkage Report:**
   - Generates a machine- and human-readable report (`TESTING_JIG_REPORT.md` / `.json`) listing: module inventory, JaCoCo unit line coverage per module, functional/instrumented coverage (`UNMEASURED` until device tests run), UC-01..UC-13 test linkage, and total release test cases run vs passed.
3. **Hardware Device Smoke Checklist (Flagship Phone on USB):**
   - Cold launch after removing weights → verify `"model missing"` and zero boxes.
   - Host SHA-256 verification + install of `ssd_mv2_160_u8` → Refresh → Load → Live AI view shows boxes, `"Second camera not used on this build"`, and `"model loaded, accelerator unverified"`.
   - Required model removal → verify return to `"model missing"` and zero boxes.
   - Kiosk escape rehearsal: enter `Helmet` and `Chest` (verify touch is dead across landscape recreation), hold both volume keys 3 s → verify return to `Handheld` within \(\le 5\text{ s}\).
