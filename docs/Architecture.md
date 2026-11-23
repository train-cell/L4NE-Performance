# Architecture & Multi-Platform Direction (`L4NE Training` v1.2.0)

## 1. Current Implementation

**L4NE Training** is built around a single, shared **100% deterministic Rust Core (`l4ne-core` v1.2.0)** that powers native platform clients on **iOS / macOS (`Swift 6 + SwiftUI`)** and **Android (`Kotlin + Jetpack Compose`)**.

| Component | Path | Responsibility |
| :--- | :--- | :--- |
| **`l4ne-core` (Rust)** | `crates/l4ne-core/` | Bundled SQLite Schema v3 engine (`rusqlite`), SHA-256 protocol hashing, slot expansion (`rounds × blocks`), centisecond numpad parser, live poolside timer countdown evaluator, multi-sport deterministic analytics, workout-to-template matcher, and JSON/CSV portability. |
| **`L4NECoreFFI` (C Target)** | `Sources/L4NECoreFFI/` | Exposes `crates/l4ne-core/include/l4ne_core.h` and links `target/release/libl4ne_core.a` into Swift. |
| **`L4NETrainingCore` (Swift 6)** | `Sources/L4NETrainingCore/` | Typed `Codable`/`Sendable` domain models, `L4NECoreClient` FFI bridge, `L4NEDurationFormatter`, and `L4NEHealthKitAdapter` (Read & `HKWorkout` Write). |
| **`L4NETrainingUI` (SwiftUI)** | `Sources/L4NETrainingUI/` | L4NE Dark Carbon (`#0A0C0E`) & Electric Lime (`#CCFF00`) design system, `L4NEAppStore`, `LivePoolsideTimerView`, and all 8 application screens with native `Swift Charts`. |
| **`L4NETrainingApp`** | `Sources/L4NETrainingApp/` | `@main L4NETrainingApp` entry point for iOS 17+ and macOS 14+ (`L4NETraining.xcodeproj`). |
| **`L4NETestRunner`** | `Sources/L4NETestRunner/` | 7-gate full-stack verification executable testing Swift 6 → C-ABI → Rust `l4ne-core` → SQLite Schema v3. |
| **Android JNI & Compose** | `crates/l4ne-core/src/jni_android.rs` & `android/` | Zero-dependency JNI exports (`Java_com_l4ne_training_core_L4NECoreNative_*`), `L4NECoreNative.kt`, and Jetpack Compose UI (`L4NEComposeApp.kt`). |

---

## 2. Boundary of Truth (`UI` vs `l4ne-core`)

1. **Zero UI Math:** The SwiftUI and Jetpack Compose layers never calculate averages, standard deviations, fatigue indices, SWOLF, Epley 1RM, or send-off rest budgets on their own. Even during the 20 Hz Live Poolside Timer loop, the UI passes monotonic elapsed milliseconds (`repElapsedMs`, `restElapsedMs`) to `l4ne-core` (`compute_live_timer_tick`) and renders the returned `LiveTimerTickOutput`.
2. **Protocol Versioning Invariant:** When a user edits a template, `update_template_protocol` computes the canonical SHA-256 `protocol_hash`. If the hash matches the active version, only metadata (`name`, `folder_tag`, `notes`) is updated. If any physiological parameter changed, a new immutable row in `template_versions` (`version_number + 1`) is inserted and set as `active_version_id`, leaving all previous `template_versions` and their linked `sessions` untouched.
3. **Deduplication Invariant:**
   - Imported HealthKit / Health Connect workouts store `external_source_uuid` (`UNIQUE` in `workouts`). Re-importing the same watch workout fails closed with `CoreError::DuplicateExternalWorkout`.
   - Exported L4NE sessions store `exported_external_uuid` in `sessions`. Re-exporting an already exported session fails closed with `CoreError::DuplicateExternalWorkout`.
