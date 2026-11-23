# Changelog

All notable changes to **L4NE Performance (`L4NE Training`)** are documented in this file.

## 2026-11-23 — v1.2.0: Macrocycle Folders, Intra-Rep Lap Splits, Watch Lap Auto-Prefill & Data Contract

- **SQLite Schema v3 & Resilient Migration (`crates/l4ne-core/src/db.rs`):**
  - Added `folder_tag TEXT` to `templates` for macrocycle/training phase organization (e.g., `"Race Pace / Taper"`, `"Lactate Tolerance"`, `"Aerobic Threshold"`, `"Strength Block"`).
  - Added `lap_durations_json TEXT` to `workouts` to persist recorded `HKWorkoutEvent` lap segments from imported Apple Watch workouts.
  - Added idempotent `ALTER TABLE` upgrades so existing Schema v1 and v2 databases upgrade seamlessly to Schema v3 without data loss.
- **Deterministic Apple Watch Lap-to-Slot Auto-Prefill (`prefill_reps_from_workout_laps`):**
  - Maps recorded pool lap durations (`workout.lap_durations_ms`) onto expanded `ExpectedRepSlot`s.
  - Automatically aggregates multiple consecutive pool lengths for longer pyramid/compound slots (e.g., summing two `50m` watch laps into a `100m` slot duration while preserving the individual `50m` splits in `splits_ms`).
  - Added 1-tap `Auto-Log Laps` button in `WorkoutImportView.swift`.
- **Live Poolside Companion Intra-Rep Splits (`L4NELivePoolsideView.swift`):**
  - Added `LAP SPLIT` action button during active swimming to capture intermediate turn splits (e.g., 50m splits inside a 100m or 150m repetition) with `>= 0.80s` wet-finger debounce protection.
- **Fail-Closed JSON Backup Restore Validation & JSON Schema Contract:**
  - Enforced strict fail-closed pre-transaction bounds in `import_backup_json` (max payload 32 MiB, max 10,000 templates, max 100,000 sessions, valid `schema_version` in `1..=3`).
  - Preserved all historical `TemplateVersion` records (`all_template_versions`) in portable JSON backups so sessions bound to older protocol versions (`v1`) satisfy foreign-key integrity upon restore.
  - Added machine-readable JSON Schema 2020-12 contract at `docs/contracts/l4ne-backup-v2.schema.json` and full specification in `docs/CROSS_PLATFORM_DATA_CONTRACT.md`.
- **Complete Repository Documentation Suite:**
  - Added `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `HANDOFF.md`, `LIVE_CAPABILITIES.md`, `docs/Architecture.md`, `docs/CROSS_PLATFORM_DATA_CONTRACT.md`, `docs/MATHEMATICAL_SPECIFICATION.md`, `docs/Deployment.md`, `docs/IMPLEMENTATION_STATUS.md`, `docs/Physical-acceptance.md`, and `docs/templates/physical-session.md`.
- **Verification:**
  - Rust Core unit & integration suite: **7/7 PASS** (0 warnings).
  - Swift 6 + Rust C-FFI Full-Stack Verification Runner (`L4NETestRunner`): **7/7 GATES PASS (100%)**.
  - Native `L4NETrainingApp` executable compilation & `L4NETraining.xcodeproj` generation: **PASS**.

---

## 2026-11-23 — v1.1.0: Live Poolside Companion, Multi-Sport Engine, HealthKit Write & Android JNI

- **Live Poolside Training Companion (`engine::evaluate_live_timer_tick` & `L4NELivePoolsideView.swift`):**
  - Implemented deterministic rest and send-off departure cycle state machine in Rust (`swimming`, `resting`, `sendoff_overrun`, `ready_to_depart`) with exact departure cues (`ten_sec_warning`, `five_sec_warning`, `countdown_3_2_1`, `depart_now`).
  - Built high-contrast `62pt` monospaced poolside HUD driven by monotonic uptime (`ProcessInfo.processInfo.systemUptime`) with `0.80s` wet-screen debounce protection.
- **Full Multi-Sport UI & Deterministic Analytics (`Swimming`, `Finswimming`, `Track`, `Field`, `Gym`):**
  - Added **SWOLF** efficiency calculation (`round(duration_sec) + stroke_count`) for Swimming & Finswimming.
  - Added **Gym Strength** analytics (`WeightReps`): Total Session Tonnage ($\sum w_i \times r_i$ in kg) and **Epley Estimated 1-Rep Max** ($1\text{RM} = w \times (1 + r/30)$).
  - Added **Field Throws/Jumps** analytics (`DistanceAttempt`): Best Valid Attempt ($m$) and positive-direction improvement percentage.
  - Added 1-tap multi-sport presets and full per-block protocol editor in `TemplateBuilderSheet`.
- **Native Swift Charts & Interactive Session Comparison (`TemplateAnalyticsView.swift`):**
  - Added native `Charts` bar visualization for intra-session rep-by-rep pace and fatigue distribution.
  - Added interactive Current-vs-Baseline session picker with slot-by-slot delta table and automatic `PROTOCOL CHANGED (v1 → v2)` warning banner.
- **Apple HealthKit Write (`HKWorkout` Export) & Recovery Editor:**
  - Added `exportSessionToHealthKit` in `L4NEHealthKitAdapter.swift` using `HKWorkoutBuilder` and `exported_external_uuid` in SQLite to prevent duplicate HealthKit exports.
  - Added `HealthSnapshotEditorSheet` for logging or updating daily Sleep, HRV SDNN, Resting HR, and VO₂ Max.
- **Idempotent JSON Backup Restore & Android NDK JNI Bridge:**
  - Added transactional `import_backup_json` (`RestoreBackupResult`) and `get_database_diagnostics`.
  - Added zero-dependency Android JNI C-ABI exports (`crates/l4ne-core/src/jni_android.rs`), Kotlin JNI bridge (`L4NECoreNative.kt`), and Jetpack Compose UI (`L4NEComposeApp.kt`).

---

## 2026-11-23 — v0.1.0 (v1.0 MVP): Rust Core (`l4ne-core`), Protocol Versioning & SwiftUI App

- Initialized public open-source monorepo `train-cell/L4NE-Performance` (`a429eae`) under **GNU GPL v3.0 (`GPL-3.0-only`)** with proprietary brand protection in `TRADEMARK.md`.
- Implemented `l4ne-core` in Rust with bundled SQLite (`rusqlite`), canonical SHA-256 protocol hashing, automatic `TemplateVersion` incrementing, slot expansion for homogeneous sets, pyramids, and multi-round compound sets, Athletic Centisecond Numpad parser (`"3240"` → `32.40s`), deterministic workout-to-template matcher, daily training timeline without volume double-counting, and JSON/CSV export.
- Implemented Swift 6 `L4NETrainingCore` C-FFI client and `L4NETrainingUI` with the **L4NE Dark Carbon (`#0A0C0E`) & Electric Lime (`#CCFF00`)** design system.
