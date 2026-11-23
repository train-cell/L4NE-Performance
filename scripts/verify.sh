#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== [1/3] Running Rust Core Unit & Integration Tests (cargo test) ==="
cargo test --workspace

echo "=== [2/3] Building Optimized Rust Static Library (libl4ne_core.a) ==="
cargo build --release

echo "=== [3/3] Compiling & Running Swift 6 + SwiftUI + Rust FFI Verification Suite ==="
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
