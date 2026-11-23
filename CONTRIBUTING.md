# Contributing & Development Guide

Read [README.md](README.md), [HANDOFF.md](HANDOFF.md), [TRADEMARK.md](TRADEMARK.md), and [docs/ARCHITECTURE_MVP.md](docs/ARCHITECTURE_MVP.md) before modifying protocol, database, or analytics behavior. Keep changes surgical, deterministic, and verifiable.

## 1. Architectural Invariants (Non-Negotiable)

1. **100% Deterministic Core (`crates/l4ne-core`):**
   - All mathematical analytics, SHA-256 protocol hashing, slot expansions (`rounds × blocks`), centisecond numpad parsing, live poolside timer countdown math, and SQLite transactions execute inside `l4ne-core` (Rust).
   - Platform UI layers (`SwiftUI` on iOS/macOS, `Jetpack Compose` on Android) must **never** duplicate mathematical formulas or mutate SQLite tables directly.
2. **Integer Milliseconds Only (`i64`):**
   - Never store durations or paces as floating-point seconds (`f32`/`f64`) in SQLite or JSON contracts. Every duration is an integer millisecond (`duration_ms: i64`).
3. **Immutable Protocol Versioning:**
   - Editing a template's physiological parameters (distance, repetitions, rounds, rest mode, rest/send-off duration, stroke/movement, pool length, or equipment) changes its SHA-256 `protocol_hash` and **must** mint a new `TemplateVersion` (`v + 1`). Historical sessions must never be retroactively mutated.
4. **Observational Health Context:**
   - HealthKit / Health Connect comparisons (Sleep, HRV, Resting HR, VO₂ Max) must always be presented as **observational correlations**, never as proven causal claims.

## 2. Automated Verification Pipeline

Run the 4-stage verification script before every commit:

```bash
./scripts/verify.sh
```

This script executes:
1. `cargo test --workspace` — Runs all Rust unit and integration tests in `l4ne-core`.
2. `cargo build --release` — Builds the optimized `libl4ne_core.a` static library with bundled SQLite.
3. `swiftc ... -o .build/verify/L4NETestRunner && .build/verify/L4NETestRunner` — Compiles and runs all 7 full-stack Swift 6 + SwiftUI + Rust C-FFI verification gates.
4. `swiftc ... -o .build/verify/L4NETrainingApp && python3 generate_project.py` — Verifies that the native `@main L4NETrainingApp` executable compiles cleanly and regenerates `L4NETraining.xcodeproj`.

## 3. TDD & Evidence Policy

- Every behavioral or mathematical change requires a failing test first (**RED → GREEN → REFACTOR**).
- Never claim physical device, poolside water-lock, or Apple Watch sensor validation from a desktop build or simulator check. Physical acceptance is tracked separately using [docs/Physical-acceptance.md](docs/Physical-acceptance.md).
- Never commit API keys, Apple signing certificates, provisioning profiles, `.ipa` binaries, local `.sqlite` database files, or personal HealthKit exports.
