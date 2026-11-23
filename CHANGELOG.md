# Changelog

All notable changes to **L4NE Performance (`L4NE Training`)** are documented in this file.

## 2026-11-23 — v1.3.0: Minimalist Graphite / Bevel / Strava Multi-Theme System, Bevel Rings, Strava Split Bars & Screen 7 Health Context

- **Multi-Theme Engine (`ThemePreset` & `app_settings` in SQLite Schema v4):**
  - Added 5 persisted themes across Rust (`l4ne-core`), iOS/macOS (`L4NEPalette` in `L4NETheme.swift`), and Android (`L4NEAndroidTheme` in `L4NEComposeApp.kt`):
    1. `graphite_bevel` (*Graphite Bevel* — Default minimalist titanium graphite with top-edge specular bevel cards & Electric Lime).
    2. `strava_obsidian` (*Strava Athletic Obsidian* — Obsidian slate with Signal Orange `#FC4C02` & Gold PR medals).
    3. `bevel_navy` (*LoggedIn Bevel Navy* — Faithful transfer of the `LoggedInTheme` `#0F172A` / `#16213A` palette with Electric Cyan `#38BDF8` & Amber `#EAB308`).
    4. `lane4_carbon` (*L4NE Pure Carbon & Lime* — High-contrast OLED black `#060709` for wet poolside legibility).
    5. `minimal_alabaster` (*Minimalist Lab Daylight* — Clean alabaster light mode `#F3F4F6` / `#FFFFFF` with deep graphite ink).
- **Bevel Concentric Rings Cockpit (`L4NEBevelRingsCard`) & Tactile Modifiers:**
  - Ported the triple concentric Bevel ring geometry (`Recessed Disc + Bezel Stefani Lip + Volume Load / Protocol Consistency / Recovery Context Rings`) and `.l4neBevelCard` / `L4NETactileBevelButtonStyle` spring modifiers.
  - Enforced the `"Unknown != 0"` invariant (`Option<f64>` renders an empty recessed track when HealthKit samples are absent).
- **Strava-Inspired Activity Feed Cards & Horizontal Split Pace Bars (`L4NEStravaSplitsBarView`):**
  - Every session card now displays a Strava 3-column hero metrics strip, `NEG SPLIT` and `HK EXPORTED` badges, and horizontal velocity bars for each repetition highlighting the fastest rep with a Gold Medal (`medal.fill`).
- **Dedicated Screen 7 (`HealthContextView`) & Personal Recovery Baselines (`compute_health_context_summary`):**
  - Computes deterministic personal rolling baselines and latest deltas for Sleep duration, HRV SDNN, Resting Heart Rate, and VO₂ Max with strictly observational correlation notes.
- **Complete Overview Examples A, B, C & 7-Step Workout Import Standalone Option:**
  - Seeded all 3 explicit template protocols from Overview Section 3 (`8×50m — 30s rest, monofin`, `6×100m — 60s rest`, `6×100m — 30s rest`) plus Pyramid (`50-100-150-100-50m`) and Compound Send-Off (`4×[2×50+100]`).
  - Added `set_workout_standalone` (`Keep Standalone`) and live `associated_templates_count` (`Associated templates: N`) on imported workouts.
  - Added `INFOPLIST_KEY_NSHealthShareUsageDescription` and `INFOPLIST_KEY_NSHealthUpdateUsageDescription` to `L4NETraining.xcodeproj`.
- **Segmented PCr Race Predictor & Interactive Recalculator (`calculate_pcr_prediction` & `PcrRecalculatorSheet`):**
  - Implemented the Segmented PCr Model (`Recovery = 1 - e^(-t/τ)`, `Δ = k·Recovery + FF`, `τ = 28s`, `k = 0.16` for 200m, `k = 0.13` for 400m) in `crates/l4ne-core/src/analytics.rs`.
  - Automatically distinguishes **Segmented PCr Mode** (0% penalty on Segment 1 when `d_1 > 150m`, matching Case Study A `200m + 20s + 150m → 2:53.59`) and **Symmetric Broken Set Mode** (matching Case Study B `4×50m @ 15s → 76.99s / 1:17.00`).
  - Automatically derives `200m`, `400m`, and `800m` PCr Race Predictions per template (`4×50m → 200m & 400m`, `8×50m → 200m & 400m`, `4×100m → 200m & 400m`, `6×100m → 200m & 400m`, Pyramid & Compound sets).
- **Left-to-Right Centisecond Numpad, Sport-Specific Equipment Catalog & Template Deletion:**
  - Updated `parse_athletic_numpad` to parse progressively from left to right (`"3"` → `3.00s`, `"32"` → `32.00s`, `"324"` → `32.40s`, `"3240"` → `32.40s`).
  - Added full sport-specific equipment catalogs for **Τεχνική Κολύμβηση** (`Μονοπέδιλο`, `Αναπνευστήρας`, `Μάσκα`, `Φιάλη Οξυγόνου`, `Διπλά Πέδιλα`, `Σανίδα`), **Κλασική Κολύμβηση** (`Γυαλάκια`, `Χεράκια (Paddles)`, `Pull Buoy`, `Σανίδα (Kickboard)`, `Πεδιλάκια Κολύμβησης`, `Αναπνευστήρας`, `Αλεξίπτωτο Αντίστασης`), **Στίβο (Track)**, **Κονίστρα (Field)**, and **Γυμναστήριο (Gym)**.
  - Added transactional `delete_template` across Rust SQLite, C-FFI, and SwiftUI (`Cockpit`, `TemplatesLibraryView`, and `TemplateBuilderSheet`).
- **Verification:**
  - Rust Core unit & integration suite: **8/8 PASS** (0 warnings).
  - Swift 6 + Rust C-FFI Full-Stack Verification Runner (`L4NETestRunner`): **9/9 GATES PASS (100%)**.
  - Native `L4NETrainingApp` executable compilation & `L4NETraining.xcodeproj` iOS Simulator build: **PASS**.

---

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
