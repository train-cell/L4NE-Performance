# L4NE Performance — L4NE Training

> **SPORTS TECHNOLOGY · TRAINING · ANALYTICS**  
> **BUILT TO OUTPERFORM.**

**L4NE Training** is a local-first, 100% deterministic athletic training protocol logger and performance analytics engine created under the **L4NE Performance** brand (inspired by **Lane 4** — traditionally the fastest lane in competitive swimming and finswimming).

 Athletes define reusable training protocols (**Templates** — from homogeneous interval sets like `8 × 50m Surface Monofin @ 30s rest` to complex **Pyramids** `50-100-150-100-50m` and **Multi-Round Send-Off Compound Sets** `4 × [2×50m @ 0:50 + 1×100m @ 1:40]`), log each execution in seconds via an **Athletic Centisecond Numpad**, optionally enrich workouts with **Apple HealthKit** & **Apple Watch** data, and measure true physical evolution over time.

**No AI. No LLMs. No unnecessary cloud. Just training data, deterministic mathematics, and measurable progress.**

---

## 1. Core Product Principles

1. **100% Deterministic Mathematics:** All metrics, comparisons, fatigue indices, and workout-to-template matching rules execute via explicit mathematical formulas in Rust (`l4ne-core`). All durations are stored as integer milliseconds (`i64`) with zero floating-point drift.
2. **Local-First & Private by Design:** All data is stored locally on the athlete's device in SQLite (`rusqlite` bundled). No account, no remote server, and no internet connection required. Full portable JSON Backup/Restore and CSV Export are built in.
3. **Historical Protocol Integrity (Template Versioning):** Every template protocol computes a canonical **SHA-256 fingerprint** across sport category, pool length, rounds, equipment, distances, strokes, and rest/send-off intervals. If an athlete modifies a template later, a new immutable `TemplateVersion` (`v2`, `v3`, ...) is minted automatically while historical sessions remain permanently bound to the exact protocol version under which they were performed.
4. **Homogeneous Sets, Pyramids & Compound Rounds (v1.0):**
   - **Homogeneous Sets:** e.g. `8 × 50m Surface Monofin @ 30s Rest`
   - **Pyramids:** e.g. `50m - 100m - 150m - 100m - 50m (Bifins)` with slot-by-slot historical delta comparison (`Slot #3: 150m` today vs `Slot #3: 150m` baseline)
   - **Multi-Round Send-Off Sets:** e.g. `4 × [2×50m @ 0:50 + 1×100m @ 1:40]` with automatic calculation of **Actual Rest** (`SendOff - RepDuration`)
5. **Observational HealthKit Context:** Pairs session performance with Apple HealthKit recovery metrics (Sleep duration, HRV SDNN, Resting Heart Rate, VO₂ Max) and presents **observational correlations — never unproven causal claims**.

---

## 2. Multi-Platform Architecture (`l4ne-core` in Rust + Native SwiftUI)

```text
L4NE-Performance/
├── LICENSE                         # GNU GPL v3.0 (GPL-3.0-only)
├── TRADEMARK.md                    # L4NE Performance Brand & Trademark Protection Policy
├── README.md
├── Cargo.toml                      # Rust Workspace
├── Package.swift                   # Swift 6 Package (L4NECoreFFI, L4NETrainingCore, L4NETrainingUI)
├── crates/
│   └── l4ne-core/                  # Shared Multi-Platform Rust Core (iOS & Android)
│       ├── include/l4ne_core.h     # C-ABI Header for Swift & Kotlin/JNI
│       └── src/
│           ├── lib.rs              # Public API & Rust integration test suite
│           ├── models.rs           # Multi-sport domain models (Swimming, Finswimming, Track, Field, Gym)
│           ├── engine.rs           # Slot expansion, SHA-256 protocol hashing, Centisecond Numpad parser
│           ├── analytics.rs        # Deterministic Pace, Consistency CV%, Fatigue Index %, Slot Deltas
│           ├── matcher.rs          # Deterministic Apple HealthKit workout-to-template matcher
│           ├── db.rs               # Bundled SQLite storage, migrations, versioning, JSON/CSV exports
│           └── ffi.rs              # C-ABI JSON command bridge
├── Sources/
│   ├── L4NECoreFFI/                # C-FFI Target linking libl4ne_core.a
│   ├── L4NETrainingCore/           # Swift 6 Core Client, Models, Formatter & HealthKit Adapter
│   └── L4NETrainingUI/             # SwiftUI App Screens & L4NE Dark/Electric Lime (#CCFF00) Theme
├── Tests/
│   └── L4NETrainingCoreTests/      # End-to-End Swift XCTest suite calling into Rust l4ne-core
├── android/                        # Android NDK & Jetpack Compose integration guide
└── docs/
    ├── L4NE_Performance_Project_Overview.md
    └── ARCHITECTURE_MVP.md
```

---

## 3. Deterministic Performance Formulas

Given $N$ valid repetitions with durations $t_1, t_2, \dots, t_N$ (in milliseconds) and distances $d_1, d_2, \dots, d_N$ (in meters):

- **Total Active Duration:**
  $$T_{\text{total}} = \sum_{i=1}^{N} t_i$$
- **Weighted Pace per 100m (works across both Homogeneous Sets & Pyramids):**
  $$P_{100} = \frac{\sum_{i=1}^{N} t_i}{\sum_{i=1}^{N} d_i} \times 100$$
- **Consistency Score (Coefficient of Variation $\text{CV}\%$):**
  $$\text{CV}(\%) = \left(\frac{\sigma}{\mu}\right) \times 100$$
- **Fatigue / Pace Degradation Index ($\text{First Half}$ vs $\text{Second Half}$):**
  $$\text{Fatigue}(\%) = \frac{P_{\text{second\_half}} - P_{\text{first\_half}}}{P_{\text{first\_half}}} \times 100$$
  *(Negative values indicate a **negative split** — finishing the set faster than starting).*
- **Actual Rest Earned on Send-Off Cycle $S$:**
  $$R_i = \max(0, S - t_i)$$
- **Historical Improvement (%):**
  $$\text{Improvement}(\%) = \frac{T_{\text{baseline}} - T_{\text{current}}}{T_{\text{baseline}}} \times 100$$

---

## 4. Build & Verification Instructions

### Step 1: Build & Test the Rust Core (`l4ne-core`)
```bash
cargo test --workspace
cargo build --release
```

### Step 2: Build & Test the Swift 6 Package & SwiftUI Layer (`L4NETraining`)
*(Requires `cargo build --release` first so `target/release/libl4ne_core.a` is present for the Swift linker).*
```bash
swift test
```

---

## 5. License & Trademark Protection

- **Source Code License:** Licensed under the **GNU General Public License v3.0 (`GPL-3.0-only`)**. See [LICENSE](LICENSE).
- **Brand & Trademark Policy:** The names **L4NE**, **L4NE Performance**, **L4NE Training**, **L4NE Analytics**, **L4NE Labs**, the stylized **L4NE** wordmark, and visual assets are proprietary trademarks of **John Akrivos**. Public redistribution of forks under the **L4NE** brand is strictly prohibited. See [TRADEMARK.md](TRADEMARK.md).
