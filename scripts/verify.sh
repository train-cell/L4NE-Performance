#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== [1/4] Running Rust Core v1.1.0 Unit & Integration Tests (cargo test) ==="
cargo test --workspace

echo "=== [2/4] Building Optimized Rust Static Library (libl4ne_core.a) ==="
cargo build --release

echo "=== [3/4] Compiling & Running Swift 6 + SwiftUI + Rust FFI v1.1.0 Verification Suite ==="
mkdir -p .build/verify
swiftc \
    -O \
    -parse-as-library \
    -import-objc-header crates/l4ne-core/include/l4ne_core.h \
    Sources/L4NETrainingCore/*.swift \
    Sources/L4NETrainingUI/*.swift \
    Sources/L4NETestRunner/main.swift \
    -L target/release \
    -ll4ne_core \
    -o .build/verify/L4NETestRunner

.build/verify/L4NETestRunner

echo "=== [4/4] Compiling Native L4NETrainingApp Executable & Generating Xcode Project ==="
swiftc \
    -O \
    -parse-as-library \
    -import-objc-header crates/l4ne-core/include/l4ne_core.h \
    Sources/L4NETrainingCore/*.swift \
    Sources/L4NETrainingUI/*.swift \
    Sources/L4NETrainingApp/L4NETrainingApp.swift \
    -L target/release \
    -ll4ne_core \
    -o .build/verify/L4NETrainingApp

python3 generate_project.py
echo "✅ L4NETrainingApp native binary (.build/verify/L4NETrainingApp) and L4NETraining.xcodeproj verified."
