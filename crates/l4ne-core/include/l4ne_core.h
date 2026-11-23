#ifndef L4NE_CORE_H
#define L4NE_CORE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Returns the semantic version of the L4NE Core Rust engine ("1.2.0", static string, do not free).
 */
const char* l4ne_core_version(void);

/**
 * Initializes or migrates the local SQLite database at `db_path` (or ":memory:")
 * to schema v2 (L4NE Training v1.1) and optionally seeds initial multi-sport demo protocols.
 * Caller MUST free the returned pointer using `l4ne_string_free`.
 */
char* l4ne_init_database_json(const char* db_path, bool seed_demo);

/**
 * Executes a deterministic v1.1 command against the SQLite database at `db_path` using a JSON payload.
 * Supported actions in `request_json`:
 *   - `list_templates` (optional `include_archived: bool`)
 *   - `get_template` (`template_id`)
 *   - `list_template_versions` (`template_id`)
 *   - `create_template` (`payload`, `now_ms`)
 *   - `update_template_protocol` (`payload`, `now_ms`)
 *   - `set_template_archived` (`template_id`, `is_archived`, `now_ms`)
 *   - `expand_template_slots` (`template_version_id`)
 *   - `log_session` (`payload`, `now_ms`)
 *   - `delete_session` (`session_id`)
 *   - `link_session_to_workout` (`session_id`, `workout_id`)
 *   - `mark_session_exported` (`session_id`, `external_uuid`)
 *   - `list_sessions` (optional `template_id`)
 *   - `template_analytics` (`template_id`)
 *   - `compare_sessions` (`current_session_id`, `baseline_session_id`)
 *   - `import_workout` (`payload`, `now_ms`)
 *   - `list_workouts`
 *   - `match_workout_templates` (`workout_id`)
 *   - `upsert_health_snapshot` (`payload`)
 *   - `list_health_snapshots`
 *   - `daily_timeline` (`date_iso`)
 *   - `parse_numpad` (`digits`)
 *   - `compute_live_timer_tick` (`payload`)
 *   - `export_json` (`now_ms`)
 *   - `import_json` (`backup_json`)
 *   - `export_csv`
 *   - `database_stats`
 * Caller MUST free the returned pointer using `l4ne_string_free`.
 */
char* l4ne_execute_json(const char* db_path, const char* request_json);

/**
 * Frees a UTF-8 C string previously allocated and returned by `l4ne-core`.
 */
void l4ne_string_free(char* ptr);

#ifdef __cplusplus
}
#endif

#endif /* L4NE_CORE_H */
