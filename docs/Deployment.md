# Building & Deploying `L4NE Training` (iOS, macOS & Android)

## 1. Local macOS & iOS Build via Xcode (`L4NETraining.xcodeproj`)

1. **Build the Rust static library first:**
   ```bash
   cargo build --release
   ```
   This produces `target/release/libl4ne_core.a` with bundled SQLite 3.
2. **Generate or refresh the Xcode project:**
   ```bash
   python3 generate_project.py
   ```
3. **Open in Xcode:**
   - Open `L4NETraining.xcodeproj` and select the `L4NETraining` scheme.
   - Under **Signing & Capabilities**, choose your Apple Team, enable **Automatic Signing**, and add the **HealthKit** capability when testing live Apple Health reads/writes on a physical iPhone.
   - Preserve the bundle identifier `com.l4ne.training` when updating an existing installation so the local SQLite database inside the app sandbox is retained.

---

## 2. iOS Distribution Paths & Signing Constraints

- **Personal Xcode Development (Free Apple ID):** Installs directly onto a USB/Wi-Fi connected personal iPhone with Developer Mode enabled. Provisioning profiles under a free Apple ID typically expire after **7 days** and require re-signing via Xcode.
- **Apple Developer Program (99 USD/year):** Required for 1-year development provisioning, **TestFlight** beta distribution (up to 90 days per build; testers do not need paid developer accounts), and official **App Store** distribution.
- **GitHub Source vs `.ipa` Binaries:** Publishing source code or unsigned `.ipa` files on GitHub does not bypass iOS code-signing requirements. Every iOS installation requires a valid provisioning profile for the target device or distribution channel.

---

## 3. Cross-Compiling `l4ne-core` for iOS Device / Simulator & Android NDK

### iOS Hardware (`arm64`) & Simulator (`aarch64-apple-ios-sim`)
```bash
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
cargo build --release -p l4ne-core --target aarch64-apple-ios
cargo build --release -p l4ne-core --target aarch64-apple-ios-sim
```

### Android NDK (`libl4ne_core.so`)
```bash
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
cargo build --release -p l4ne-core --target aarch64-linux-android
```
Copy `target/aarch64-linux-android/release/libl4ne_core.so` into `android/app/src/main/jniLibs/arm64-v8a/libl4ne_core.so` so `System.loadLibrary("l4ne_core")` in `L4NECoreNative.kt` loads the native engine at runtime.
