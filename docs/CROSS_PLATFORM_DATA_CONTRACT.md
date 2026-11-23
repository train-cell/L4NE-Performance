# Cross-Platform Local Data Contract (`L4NE Training` v1.2.0)

Updated: 2026-11-23 (`l4ne-core` v1.2.0, SQLite Schema v3)

## 1. Purpose & Scope

This document specifies the exact binary, SQLite, and JSON encoding contract shared by:
- **Rust Core (`crates/l4ne-core`)**
- **iOS / macOS Client (`Sources/L4NETrainingCore`)**
- **Android Client (`android/app/src/main/java/com/l4ne/training/core`)**

A machine-readable JSON Schema 2020-12 profile for portable database backups is maintained at [`contracts/l4ne-backup-v2.schema.json`](contracts/l4ne-backup-v2.schema.json).

---

## 2. Time, Duration & Numeric Encoding Rules

1. **Durations (`duration_ms`, `rest_or_sendoff_ms`, `round_rest_ms`, `actual_rest_ms`):**
   - Always encoded as signed 64-bit integer milliseconds (`i64` in Rust, `Int64` in Swift, `Long` in Kotlin).
   - Floating-point seconds (`32.4`) are **forbidden** in persistence and FFI payloads.
   - Centisecond numpad inputs (`"3240"`) map deterministically to integer milliseconds (`32_400`).
2. **Timestamps (`created_at_ms`, `updated_at_ms`, `performed_at_ms`, `started_at_ms`, `captured_at_ms`):**
   - Always encoded as UNIX epoch milliseconds (`i64` UTC).
   - Calendar day grouping (`date_iso`) uses canonical 10-character ISO-8601 date strings (`"YYYY-MM-DD"`).
3. **Identifiers (`id`):**
   - Time-ordered **UUID v7** lowercase hyphenated strings (`8-4-4-4-12` hex, e.g., `"019356a0-7c00-7000-8000-000000000001"`).

---

## 3. Canonical SHA-256 Protocol Hash Grammar

Two template protocols are considered physiologically equivalent if and only if their `protocol_hash` strings match. The canonical pre-image string hashed by `engine::compute_protocol_hash` is:

```text
sport=<sport_category>|pool=<Option<i32>>|env=<environment>|rounds=<i32>|round_rest=<i64>|eq=<sorted_deduped_lowercase_csv>|blocks=[#0:count=<i32>,kind=<record_kind>,dist=<Option<i32>>,stroke=<trimmed_lowercase>,rest_mode=<rest_mode>,rest_ms=<i64>];...
```

- Changing `name`, `folder_tag`, `notes`, or `target_pace_ms_per_100m` does **not** alter `protocol_hash`.
- Changing `sport_category`, `pool_length_m`, `environment`, `rounds`, `round_rest_ms`, `equipment`, or any block's `repeat_count`, `record_kind`, `distance_m`, `stroke_or_movement`, `rest_mode`, or `rest_or_sendoff_ms` produces a new SHA-256 digest and mints `version_number + 1`.

---

## 4. Portable JSON Backup Contract & Fail-Closed Restore Limits

The top-level `DatabaseBackupPayload` JSON object emitted by `export_json` and consumed by `import_json` contains:

| Field | Type | Rule |
| :--- | :--- | :--- |
| `schema_version` | integer | Must be `1`, `2`, or `3` (current writer emits `2`/`3`). Any other value is rejected before opening a transaction. |
| `exported_at_ms` | integer (`i64`) | UNIX epoch milliseconds when the backup was generated. |
| `templates` | array of `TemplateWithVersion` | Active and archived templates with their current `active_version`. |
| `all_template_versions` | array of `TemplateVersion` | Complete historical version chain (`v1..vN`) for every template so historical sessions satisfy foreign-key constraints on `template_version_id`. |
| `workouts` | array of `Workout` | Imported and manual workouts, deduplicated by `id` and `external_source_uuid`. |
| `sessions` | array of `SessionWithReps` | Completed template executions with denormalized summary metrics and ordered `reps`. |
| `health_snapshots` | array of `DailyHealthSnapshot` | Daily recovery snapshots keyed by `date_iso` (`YYYY-MM-DD`). |

### Fail-Closed Restore Bounds

| Guard | Limit | Behavior on Violation |
| :--- | :--- | :--- |
| Maximum JSON payload size | `32 MiB` (`33,554,432` bytes) | Reject immediately before JSON parsing or SQLite transaction; existing database stays untouched. |
| Supported `schema_version` | `1..=3` | Reject with `CoreError::Validation`; existing database stays untouched. |
| Maximum `templates` count | `10,000` | Reject before transaction. |
| Maximum `sessions` count | `100,000` | Reject before transaction. |
| Duplicate IDs on restore | Idempotent skip (`INSERT OR IGNORE`) | Existing templates, versions, workouts, and sessions with matching primary keys are preserved without error or duplication. |
