#ifndef L4NE_CORE_H
#define L4NE_CORE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Returns the semantic version of the L4NE Core Rust engine (static string, do not free).
 */
const char* l4ne_core_version(void);

/**
 * Initializes or migrates the local SQLite database at `db_path` (or ":memory:")
 * and optionally seeds initial Swimming & Finswimming demo protocols when `seed_demo` is true.
 * Returns a newly allocated JSON string: `{"ok": true, "data": ...}` or `{"ok": false, "error": "..."}`.
 * Caller MUST free the returned pointer using `l4ne_string_free`.
 */
char* l4ne_init_database_json(const char* db_path, bool seed_demo);

/**
 * Executes a deterministic command against the SQLite database at `db_path` using a JSON payload.
 * Supported actions in `request_json`:
 *   - `{"action": "list_templates"}`
 *   - `{"action": "create_template", "payload": ...}`
 *   - `{"action": "update_template_protocol", "payload": ...}`
 *   - `{"action": "expand_template_slots", "template_version_id": "..."}`
 *   - `{"action": "log_session", "payload": ...}`
 *   - `{"action": "list_sessions", "template_id": "..."}`
 *   - `{"action": "template_analytics", "template_id": "..."}`
 *   - `{"action": "compare_sessions", "current_session_id": "...", "baseline_session_id": "..."}`
 *   - `{"action": "import_workout", "payload": ...}`
 *   - `{"action": "match_workout_templates", "workout_id": "..."}`
 *   - `{"action": "upsert_health_snapshot", "payload": ...}`
 *   - `{"action": "daily_timeline", "date_iso": "YYYY-MM-DD"}`
 *   - `{"action": "parse_numpad", "digits": "3240"}`
 *   - `{"action": "export_json"}`
 *   - `{"action": "export_csv"}`
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
