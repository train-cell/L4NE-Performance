# L4NE Training — Android Multi-Platform Target (Jetpack Compose + `l4ne-core`)

The **L4NE Training** architecture is designed so that **100% of the business logic, SQLite storage, template protocol versioning, and deterministic analytics** live in the shared Rust crate [`crates/l4ne-core`](../crates/l4ne-core).

## Shared Native Boundary

1. **Cross-compilation targets for Android NDK:**
   ```bash
   rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
   cargo build --release -p l4ne-core --target aarch64-linux-android
   ```
2. **C-ABI Header:** [`crates/l4ne-core/include/l4ne_core.h`](../crates/l4ne-core/include/l4ne_core.h) exposes `l4ne_init_database_json`, `l4ne_execute_json`, and `l4ne_string_free`.
3. **Android Health Connect Integration (v1.1 Roadmap):**
   - Just as `L4NEHealthKitAdapter.swift` maps Apple `HKWorkout` and daily recovery samples into `ImportWorkoutInput` and `DailyHealthSnapshot` on iOS, the Android adapter maps `ExerciseSessionRecord`, `HeartRateVariabilityRmssdRecord`, and `SleepSessionRecord` from **Android Health Connect** into the identical `l4ne-core` JSON commands.
