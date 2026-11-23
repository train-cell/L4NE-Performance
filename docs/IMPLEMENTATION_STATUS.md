# Implementation Status — `L4NE Training` v1.2.0

Updated: 2026-11-23. Base repository: `https://github.com/train-cell/L4NE-Performance` (`main` branch).

This table records the exact implementation and verification state of every subsystem in this checkout. Local automated software verification (`./scripts/verify.sh`) has been executed and passed 100%; physical iPhone poolside testing and Android device NDK packaging remain separate hardware acceptance steps ([Physical-acceptance.md](Physical-acceptance.md)).

| Feature / Subsystem | Source Path(s) | Current Status & Verification Evidence |
| :--- | :--- | :--- |
| **SQLite Schema v3 & Migrations (`v1 → v2 → v3`)** | `crates/l4ne-core/src/db.rs` | **Implemented & Verified.** Bundled SQLite 3 (`rusqlite`), foreign keys enforced, idempotent `ALTER TABLE` upgrades tested in Rust and Swift FFI gates. |
| **Homogeneous, Pyramid & Compound Slot Expansion** | `crates/l4ne-core/src/engine.rs` | **Implemented & Verified.** Deterministically flattens `rounds × blocks` up to 500 slots (`8×50m`, `50-100-150-100-50m`, `4×[2×50+100]`). |
| **Immutable SHA-256 Protocol Versioning (`v1..vN`)** | `crates/l4ne-core/src/engine.rs`, `db.rs` | **Implemented & Verified.** Modifying physiological fields mints `v + 1`; historical sessions remain bound to their execution version. |
| **Macrocycle / Folder Organization (v1.2)** | `crates/l4ne-core/src/db.rs`, `L4NEScreens.swift` | **Implemented & Verified.** `folder_tag` persisted in `templates`, displayed in library cards, and editable in `TemplateBuilderSheet`. |
| **Athletic Centisecond Numpad** | `crates/l4ne-core/src/engine.rs`, `L4NEScreens.swift` | **Implemented & Verified.** Positional centisecond parser (`3240` → `32.40s`, `10855` → `1:08.55`), `SAME PREV`, `±0.10s`, `SKIP`, Stroke Count, RPE. |
| **Live Poolside Companion & Intra-Rep Splits (v1.1/v1.2)** | `crates/l4ne-core/src/engine.rs`, `L4NELivePoolsideView.swift` | **Implemented & Verified.** Monotonic uptime clock, `0.80s` wet-finger debounce, `LAP SPLIT` capture, Fixed Rest & Send-Off departure cues (`-10s`, `-5s`, `3-2-1`, `GO!`). |
| **Multi-Sport Deterministic Analytics** | `crates/l4ne-core/src/analytics.rs` | **Implemented & Verified.** Weighted Pace/100m, StdDev $\sigma$, Consistency $\text{CV}\%$, Fatigue Index $\%$, Send-Off Actual Rest, SWOLF, Gym Tonnage, Epley 1RM, Field Best Attempt. |
| **Native Swift Charts & Session Comparison** | `Sources/L4NETrainingUI/L4NEScreens.swift` | **Implemented & Verified.** `Charts` rep-by-rep bar curve, interactive Current-vs-Baseline session picker, slot-by-slot Pyramid delta table. |
| **HealthKit Read, Write (`HKWorkout`) & Lap Prefill (v1.2)** | `L4NEHealthKitAdapter.swift`, `matcher.rs`, `db.rs` | **Implemented & Verified in Software.** Duplicate guards on `external_source_uuid` and `exported_external_uuid`; `prefill_reps_from_workout_laps` sums watch laps across pyramid slots. Physical iPhone HealthKit consent test pending. |
| **Fail-Closed JSON Backup/Restore & CSV Export** | `crates/l4ne-core/src/db.rs`, `docs/contracts/` | **Implemented & Verified.** 32 MiB / 10k templates / 100k sessions fail-closed bounds; restores full `all_template_versions` chain idempotently. |
| **Android NDK JNI & Jetpack Compose Client** | `crates/l4ne-core/src/jni_android.rs`, `android/` | **Source Implemented; Rust JNI Exports Compiled.** Android Gradle/NDK `.apk` build not executed on this macOS host. |
