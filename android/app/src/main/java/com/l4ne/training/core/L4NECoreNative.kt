package com.l4ne.training.core

/**
 * Native JNI Bridge to the shared Rust `l4ne-core` v1.1.0 engine (`libl4ne_core.so`).
 * All SQLite transactions, SHA-256 protocol hashing, slot expansions, live poolside timer ticks,
 * and deterministic analytics execute inside the identical Rust core used by iOS.
 */
object L4NECoreNative {
    init {
        System.loadLibrary("l4ne_core")
    }

    /**
     * Initializes/migrates the local SQLite database at [dbPath] to Schema v2
     * and optionally seeds multi-sport demo protocols.
     */
    @JvmStatic
    external fun initDatabaseJson(dbPath: String, seedDemo: Boolean): String

    /**
     * Executes any deterministic v1.1 JSON action (`list_templates`, `create_template`,
     * `update_template_protocol`, `expand_template_slots`, `log_session`, `compute_live_timer_tick`,
     * `template_analytics`, `compare_sessions`, `import_workout`, `match_workout_templates`,
     * `daily_timeline`, `parse_numpad`, `export_json`, `import_json`, `export_csv`, `database_stats`).
     */
    @JvmStatic
    external fun executeJson(dbPath: String, requestJson: String): String
}
