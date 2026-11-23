# Physical iPhone & Poolside Acceptance Protocol

Status: **not run by this document**. Record actual device observations using [the session record template](templates/physical-session.md). Passing `./scripts/verify.sh` verifies software mathematics and persistence, not wet-screen touch ergonomics or live HealthKit hardware permissions.

## 1. Preparation

1. Build `cargo build --release` and install `L4NETraining` onto your physical iPhone via Xcode (`L4NETraining.xcodeproj`).
2. Record the installed Git commit hash, iOS version, signing expiration date, and pool length (`25m` or `50m`).
3. Keep personal HealthKit exports and personal `.sqlite` files out of Git history.

## 2. Template Builder & Protocol Versioning Acceptance

- Create a Finswimming template (`8×50m Surface Monofin — 30s Rest`) and a Pyramid template (`50-100-150-100-50m Bifins`).
- Log one session using the **Athletic Centisecond Numpad** (`FAST NUMPAD LOG`). Verify that typing `1820` displays `18.20s` and `NEXT ⏎` advances to the next slot.
- Edit the template's rest interval from `30s` to `45s` and save. Verify that the template badge increments to `v2`, while the previously logged session in `TemplateAnalyticsView` still reports `v1`.

## 3. Live Poolside Companion (v1.1 / v1.2) Acceptance

- Open `LIVE TIMER` on a Send-Off template (e.g., `50m @ 0:50 Send-Off`).
- Tap `START REP #1`, test rapid double-tap (< 0.80s) to confirm the wet-finger debounce prevents premature wall finish.
- On a `100m` rep, tap `LAP SPLIT` at the 50m turn and `WALL / FINISH` at 100m. Verify both 50m segments are recorded.
- Verify the Send-Off countdown displays remaining rest (`50.00s - rep_time`) and transitions through the `-10s`, `-5s`, `3-2-1`, and `GO!` visual banners.

## 4. Apple HealthKit Read, Lap Auto-Prefill & `HKWorkout` Export

- Authorize HealthKit Read & Write permissions in the `HealthKit` tab.
- Import a swimming workout recorded by Apple Watch and verify that `Auto-Log Laps` maps the watch's 50m laps onto the selected template's slots.
- Open `TemplateAnalyticsView` and tap `Export to Apple Health`. Confirm a single workout entry appears in the iOS Fitness/Health app and the button locks to `Exported to HealthKit`.
