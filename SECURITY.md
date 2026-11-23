# Security & Local-First Privacy Policy

**L4NE Performance (`L4NE Training`)** is engineered as a **local-first, private-by-design** application.

## 1. Data Storage & Zero-Cloud Architecture

- **No Cloud Backend / No Telemetry:** The application makes zero network requests during normal operation. There are no user accounts, remote databases, analytics trackers, or AI/LLM inference endpoints.
- **Local SQLite Database:** Training protocols, sessions, repetitions, and imported workout summaries are stored locally inside the application's private sandbox (`l4ne_training_v1_1.sqlite`).
- **HealthKit & Health Connect Consent:** Reading workouts or recovery metrics (`sleepAnalysis`, `heartRateVariabilitySDNN`, `restingHeartRate`, `vo2Max`) and exporting workouts (`HKWorkout`) occur strictly after explicit OS-level user authorization.

## 2. Repository Hygiene & Sensitive Material

Do **not** commit any of the following to Git history:
- Real personal Apple HealthKit XML/JSON exports or personal `.sqlite` training databases.
- Apple Developer certificates (`.p12`, `.cer`), provisioning profiles (`.mobileprovision`), Android keystore files (`.jks`, `.keystore`), or signed `.ipa` / `.apk` / `.aab` binaries.
- Device UDIDs or personal health diagnostics.

All test fixtures and demo seeds in `crates/l4ne-core/src/db.rs` and `Sources/L4NETestRunner/main.swift` must remain 100% synthetic.

## 3. Reporting a Vulnerability

If you discover a security or data-integrity issue (such as a bounds bypass in JSON backup restoration or an FFI memory-safety defect), please report it privately to the repository owner (`John Akrivos / @train-cell`) rather than posting personal data or exploit payloads in a public issue.
