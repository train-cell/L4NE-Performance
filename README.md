# L4NE Performance — L4NE Training (v1.3.0)

<p align="center">
  <img src="Assets/l4ne-starting-block-logo.svg" alt="L4NE Starting Block #4 Official Logo" width="180" />
</p>

> **MASTER THE WATER. OWN THE LANE.**  
> **SPORTS TECHNOLOGY · TRAINING · ANALYTICS · BUILT TO OUTPERFORM.**

**L4NE Training** is a local-first, 100% deterministic athletic training protocol logger, live poolside companion, and multi-sport performance analytics engine created under the **L4NE Performance** brand (inspired by **Lane 4** — traditionally the fastest lane in competitive swimming and finswimming).

Featuring a **Minimalist Graphite, Bevel & Strava-inspired Multi-Theme UI** (with 5 persisted themes: *Graphite Bevel*, *Strava Athletic Obsidian*, *LoggedIn Bevel Navy*, *L4NE Pure Carbon & Lime*, and *Minimalist Lab Daylight*), triple concentric **Bevel Performance & Recovery Rings**, and **Strava Horizontal Split Pace Bar Cards**, athletes define reusable training protocols (**Templates** — from homogeneous interval sets like `8 × 50m Surface Monofin @ 30s rest`, `6 × 100m @ 60s rest`, `6 × 100m @ 30s rest` to complex **Pyramids** `50-100-150-100-50m`, **Multi-Round Send-Off Compound Sets** `4 × [2×50m @ 0:50 + 1×100m @ 1:40]`, **Track Sprints**, **Field Jumps/Throws**, and **Gym Strength Protocols**), record executions via the **Athletic Centisecond Numpad** or the **Live Poolside Companion Timer**, integrate with **Apple HealthKit**, and measure true physical evolution over time.

**No AI. No LLMs. No unnecessary cloud. Just training data, deterministic mathematics, and measurable progress.**

---

## 1. Full v1.2.0 Capability Matrix

| Subsystem | v1.2.0 Implementation Status |
| :--- | :--- |
| **Multi-Platform Rust Core (`l4ne-core` v1.2.0)** | Bundled SQLite Schema v3 (`rusqlite`), SHA-256 Protocol Versioning (`v1 → v2 → vN`), Macrocycle `folder_tag`, Homogeneous + Pyramid + Compound Slot Expansion, C-ABI FFI (`l4ne_core.h`) for Swift 6 & JNI (`jni_android.rs`) for Android Kotlin. |
| **Live Poolside Companion Mode (v1.1 / v1.2)** | High-contrast 62pt monospaced stopwatch using monotonic uptime (`systemUptime`), `0.80s` wet-finger debounce guard, intra-rep **`LAP SPLIT`** turn capture, deterministic **Fixed Rest** & **Send-Off Cycle** countdowns (`-10s`, `-5s`, `3..2..1..`, `DEPART NOW!`), and 1-tap SQLite session save. |
| **Post-Workout Centisecond Numpad** | Zero-punctuation digit entry (`3240` → `32.40s`, `10855` → `1:08.55`), `SAME PREV`, `±0.10s` micro-adjustments, `SKIP`, Stroke Count (`SWOLF` calculation), RPE, and live Running Average. |
| **Multi-Sport UI & Analytics** | Full support for **Finswimming** (`Surface`, `Apnea`, `Immersion`, `Bifins`), **Swimming** (`Freestyle`, `Butterfly`, `Backstroke`, `Breaststroke`, `IM`), **Track** (`TimedDistance`), **Field** (`DistanceAttempt` in meters, best attempt), and **Gym** (`WeightReps` kg × reps, Total Tonnage kg, Epley Estimated 1RM). |
| **Native Charts & Analytics** | Swift `Charts` rep-by-rep performance & fatigue curve, interactive Session-vs-Session comparison picker, slot-by-slot Pyramid deltas, Consistency `CV%`, Fatigue Index `%` (negative split detection), and observational HealthKit correlation notes. |
| **Apple HealthKit Read, Write & Lap Prefill (v1.2)** | Read authorization, deterministic workout-to-template matcher, **1-tap Watch Lap Auto-Prefill (`prefill_reps_from_workout_laps`)** across homogeneous and pyramid slots, **Write/Export (`HKWorkoutBuilder`)** with `exported_external_uuid` duplicate export protection, and Daily Recovery Snapshot editor (Sleep, HRV SDNN, Resting HR, VO₂ Max). |
| **Local-First Portability & Schema Contract** | Fail-closed **JSON Backup Export & Full Transactional JSON Restore (`import_json`)** preserving all historical `TemplateVersion` rows (`v1..vN`), JSON Schema 2020-12 contract, **CSV Export**, and live SQLite Schema v3 diagnostics. |

---

## 2. Documentation Index

### Root Documents
- [CHANGELOG.md](CHANGELOG.md) — Chronological release log across `v0.1.0`, `v1.1.0`, and `v1.2.0`.
- [LIVE_CAPABILITIES.md](LIVE_CAPABILITIES.md) — Complete matrix of live timers, formulas, and operational boundaries.
- [HANDOFF.md](HANDOFF.md) — Current engineering snapshot, verified gates, and physical acceptance boundary.
- [CONTRIBUTING.md](CONTRIBUTING.md) — Architectural invariants, TDD policy, and verification workflow.
- [SECURITY.md](SECURITY.md) — Local-first privacy architecture and sensitive-data hygiene.
- [LICENSE](LICENSE) & [TRADEMARK.md](TRADEMARK.md) — GNU GPL v3.0 license and proprietary L4NE Performance trademark protection.

### Technical & Domain Specifications (`docs/`)
- [docs/L4NE_Performance_Project_Overview.md](docs/L4NE_Performance_Project_Overview.md) — Original product discovery & vision specification.
- [docs/ARCHITECTURE_MVP.md](docs/ARCHITECTURE_MVP.md) — System architecture & SQLite DDL blueprint.
- [docs/Architecture.md](docs/Architecture.md) — Component responsibilities and FFI/JNI boundary rules.
- [docs/MATHEMATICAL_SPECIFICATION.md](docs/MATHEMATICAL_SPECIFICATION.md) — Exact formulas for Weighted Pace/100m, StdDev $\sigma$, $\text{CV}\%$, Fatigue Index $\%$, Send-Off Rest $R_i$, SWOLF, Epley 1RM, and Tonnage.
- [docs/CROSS_PLATFORM_DATA_CONTRACT.md](docs/CROSS_PLATFORM_DATA_CONTRACT.md) — Cross-platform JSON & SQLite Schema v3 encoding rules and fail-closed restore limits.
- [docs/contracts/l4ne-backup-v2.schema.json](docs/contracts/l4ne-backup-v2.schema.json) — JSON Schema 2020-12 contract for portable backups.
- [docs/IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md) — Source-vs-verified status table across iOS, macOS, Rust, and Android.
- [docs/Deployment.md](docs/Deployment.md) — Xcode device deployment, iOS code signing, and Android NDK cross-compilation.
- [docs/Physical-acceptance.md](docs/Physical-acceptance.md) & [docs/templates/physical-session.md](docs/templates/physical-session.md) — Physical iPhone & poolside acceptance checklist and session record template.

---

## 3. Build & Verification Instructions

Run the complete 4-stage automated verification pipeline (Rust unit tests, optimized `libl4ne_core.a` static build, 7-gate Swift 6 + Rust FFI verification runner, native `L4NETrainingApp` compilation, and `L4NETraining.xcodeproj` generation):

```bash
./scripts/verify.sh
```
