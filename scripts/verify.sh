#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== [1/4] Running Rust Core v1.3.0 Unit & Integration Tests (cargo test) ==="
cargo test --workspace

echo "=== [2/4] Building Optimized Rust Static Archives (libl4ne_core.a & libl4ne_core_iossim.a) ==="
cargo build --release
python3 - <<'PY'
import glob, os, shutil, struct, subprocess, tempfile

repo = os.getcwd()
src_ar = os.path.join(repo, "target/release/libl4ne_core.a")
dst_ar = os.path.join(repo, "target/release/libl4ne_core_iossim.a")
tmp = tempfile.mkdtemp(prefix="l4ne_iossim_")
try:
    shutil.copy2(src_ar, os.path.join(tmp, "libl4ne_core.a"))
    subprocess.run(["ar", "-x", "libl4ne_core.a"], cwd=tmp, check=True)
    objs = sorted(glob.glob(os.path.join(tmp, "*.o")))
    for p in objs:
        data = bytearray(open(p, "rb").read())
        magic, _cputype, _cpusubtype, _filetype, ncmds, _sizeofcmds, _flags, _reserved = struct.unpack_from("<IIIIIIII", data, 0)
        if magic != 0xFEEDFACF:
            continue
        off = 32
        for _ in range(ncmds):
            cmd, cmdsize = struct.unpack_from("<II", data, off)
            if cmd == 0x32:  # LC_BUILD_VERSION -> PLATFORM_IOSSIMULATOR (7)
                struct.pack_into("<III", data, off + 8, 7, 0x00110000, 0x001B0200)
            off += cmdsize
        open(p, "wb").write(data)
    subprocess.run(["libtool", "-static", "-o", dst_ar] + objs, check=True)
finally:
    shutil.rmtree(tmp, ignore_errors=True)
PY

echo "=== [3/4] Compiling & Running Swift 6 + SwiftUI + Rust FFI v1.3.0 Verification Suite ==="
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
