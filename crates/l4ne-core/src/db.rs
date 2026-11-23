//! SQLite Storage Engine for `l4ne-core` v1.1 (`l4ne_core::db`).
//!
//! Implements local-first persistence, template protocol versioning, session logging,
//! multi-sport metrics (Swimming, Finswimming, Track, Field, Gym), HealthKit workout
//! deduplication (both import & export), daily training timeline aggregation,
//! and full JSON Backup/Restore + CSV export.

use crate::analytics::{
    compute_actual_rest_ms, compute_health_context_summary, compute_pace_ms_per_100m,
    compute_session_metrics, compute_swolf_score, compute_template_analytics, epoch_ms_to_date_iso,
};
use crate::engine::{
    compute_protocol_hash, compute_total_distance_m, expand_template_slots,
    is_homogeneous_protocol,
};
use crate::matcher::match_workout_to_templates;
use crate::models::{
    AppSettings, CoreError, CreateTemplateInput, DailyHealthSnapshot, DailyTrainingTimeline,
    DatabaseBackupPayload, DatabaseDiagnostics, EnvironmentType, ExpectedRepSlot,
    HealthContextSummary, ImportWorkoutInput, LogSessionInput, RecordKind, RepInput, RepRecord,
    RestMode, RestoreBackupResult, SessionSummaryMetrics, SessionWithReps, SportCategory,
    TemplateAnalyticsReport, TemplateBlock, TemplateBlockInput, TemplateMatchCandidate,
    TemplateVersion, TemplateWithVersion, ThemePreset, UpdateTemplateProtocolInput, Workout,
    WorkoutSourceType,
};
use rusqlite::{params, Connection, OptionalExtension};
use std::collections::HashMap;
use uuid::Uuid;

pub struct L4neDatabase {
    conn: Connection,
}

impl L4neDatabase {
    /// Opens or creates a SQLite database at the given file path (or `":memory:"`) and runs schema v2 migrations.
    pub fn open(path: &str) -> Result<Self, CoreError> {
        let conn = if path == ":memory:" {
            Connection::open_in_memory()?
        } else {
            Connection::open(path)?
        };
        let db = Self { conn };
        db.migrate()?;
        Ok(db)
    }

    /// Runs idempotent DDL migrations for the L4NE Training v1.1 (schema v2).
    pub fn migrate(&self) -> Result<(), CoreError> {
        self.conn.execute_batch(
            r#"
            PRAGMA foreign_keys = ON;

            CREATE TABLE IF NOT EXISTS templates (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                sport_category TEXT NOT NULL,
                pool_length_m INTEGER,
                environment TEXT NOT NULL DEFAULT 'pool',
                folder_tag TEXT,
                active_version_id TEXT,
                is_archived INTEGER NOT NULL DEFAULT 0,
                created_at_ms INTEGER NOT NULL,
                updated_at_ms INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS template_versions (
                id TEXT PRIMARY KEY NOT NULL,
                template_id TEXT NOT NULL REFERENCES templates(id) ON DELETE CASCADE,
                version_number INTEGER NOT NULL,
                protocol_hash TEXT NOT NULL,
                rounds INTEGER NOT NULL DEFAULT 1,
                round_rest_ms INTEGER NOT NULL DEFAULT 0,
                equipment_json TEXT NOT NULL DEFAULT '[]',
                target_pace_ms_per_100m INTEGER,
                notes TEXT,
                total_reps INTEGER NOT NULL,
                total_distance_m INTEGER,
                is_homogeneous INTEGER NOT NULL,
                created_at_ms INTEGER NOT NULL,
                UNIQUE(template_id, version_number)
            );

            CREATE TABLE IF NOT EXISTS template_blocks (
                id TEXT PRIMARY KEY NOT NULL,
                template_version_id TEXT NOT NULL REFERENCES template_versions(id) ON DELETE CASCADE,
                block_order INTEGER NOT NULL,
                repeat_count INTEGER NOT NULL,
                record_kind TEXT NOT NULL,
                distance_m INTEGER,
                stroke_or_movement TEXT NOT NULL,
                rest_mode TEXT NOT NULL,
                rest_or_sendoff_ms INTEGER NOT NULL,
                target_duration_ms INTEGER,
                UNIQUE(template_version_id, block_order)
            );

            CREATE TABLE IF NOT EXISTS workouts (
                id TEXT PRIMARY KEY NOT NULL,
                sport_category TEXT NOT NULL,
                source_type TEXT NOT NULL,
                external_source_uuid TEXT UNIQUE,
                external_source_name TEXT,
                started_at_ms INTEGER NOT NULL,
                ended_at_ms INTEGER,
                duration_ms INTEGER,
                total_distance_m REAL,
                pool_length_m INTEGER,
                active_energy_kcal REAL,
                avg_heart_rate_bpm REAL,
                max_heart_rate_bpm REAL,
                has_route INTEGER NOT NULL DEFAULT 0,
                route_summary TEXT,
                kept_as_standalone INTEGER NOT NULL DEFAULT 0,
                lap_durations_json TEXT NOT NULL DEFAULT '[]',
                notes TEXT,
                created_at_ms INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS app_settings (
                singleton_id INTEGER PRIMARY KEY CHECK (singleton_id = 1),
                active_theme TEXT NOT NULL DEFAULT 'graphite_bevel',
                default_pool_length_m INTEGER NOT NULL DEFAULT 50,
                preferred_sport TEXT NOT NULL DEFAULT 'finswimming',
                haptics_enabled INTEGER NOT NULL DEFAULT 1,
                auto_advance_sendoff INTEGER NOT NULL DEFAULT 1,
                updated_at_ms INTEGER NOT NULL DEFAULT 0
            );

            INSERT OR IGNORE INTO app_settings (
                singleton_id, active_theme, default_pool_length_m, preferred_sport,
                haptics_enabled, auto_advance_sendoff, updated_at_ms
            ) VALUES (1, 'graphite_bevel', 50, 'finswimming', 1, 1, 1795356000000);

            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY NOT NULL,
                template_id TEXT NOT NULL REFERENCES templates(id) ON DELETE RESTRICT,
                template_version_id TEXT NOT NULL REFERENCES template_versions(id) ON DELETE RESTRICT,
                workout_id TEXT REFERENCES workouts(id) ON DELETE SET NULL,
                exported_external_uuid TEXT,
                performed_at_ms INTEGER NOT NULL,
                pool_length_m INTEGER,
                is_completed INTEGER NOT NULL DEFAULT 1,
                notes TEXT,
                total_active_duration_ms INTEGER NOT NULL DEFAULT 0,
                avg_duration_ms INTEGER,
                best_rep_duration_ms INTEGER,
                worst_rep_duration_ms INTEGER,
                avg_pace_ms_per_100m INTEGER,
                std_dev_ms REAL,
                consistency_cv_pct REAL,
                fatigue_index_pct REAL,
                total_tonnage_kg REAL,
                best_estimated_1rm_kg REAL,
                best_attempt_m REAL,
                created_at_ms INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS rep_records (
                id TEXT PRIMARY KEY NOT NULL,
                session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
                slot_index INTEGER NOT NULL,
                round_index INTEGER NOT NULL DEFAULT 1,
                block_order INTEGER NOT NULL DEFAULT 0,
                distance_m INTEGER,
                duration_ms INTEGER,
                pace_ms_per_100m INTEGER,
                actual_rest_ms INTEGER,
                stroke_count INTEGER,
                swolf_score INTEGER,
                rpe INTEGER,
                weight_kg REAL,
                reps_completed INTEGER,
                attempt_result_m REAL,
                splits_json TEXT NOT NULL DEFAULT '[]',
                is_skipped INTEGER NOT NULL DEFAULT 0,
                notes TEXT,
                UNIQUE(session_id, slot_index)
            );

            CREATE TABLE IF NOT EXISTS daily_health_snapshots (
                date_iso TEXT PRIMARY KEY NOT NULL,
                sleep_duration_minutes INTEGER,
                hrv_sdnn_ms REAL,
                resting_hr_bpm REAL,
                vo2_max_ml_kg_min REAL,
                source_summary TEXT,
                captured_at_ms INTEGER NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_sessions_template_date ON sessions(template_id, performed_at_ms DESC);
            CREATE INDEX IF NOT EXISTS idx_sessions_version_date ON sessions(template_version_id, performed_at_ms DESC);
            CREATE INDEX IF NOT EXISTS idx_workouts_date ON workouts(started_at_ms DESC);
            "#,
        )?;

        // Resilient schema v1 -> v2 -> v3 -> v4 column upgrades for pre-existing local SQLite databases
        let alter_statements = [
            "ALTER TABLE templates ADD COLUMN folder_tag TEXT",
            "ALTER TABLE workouts ADD COLUMN lap_durations_json TEXT NOT NULL DEFAULT '[]'",
            "ALTER TABLE workouts ADD COLUMN has_route INTEGER NOT NULL DEFAULT 0",
            "ALTER TABLE workouts ADD COLUMN route_summary TEXT",
            "ALTER TABLE workouts ADD COLUMN kept_as_standalone INTEGER NOT NULL DEFAULT 0",
            "ALTER TABLE sessions ADD COLUMN exported_external_uuid TEXT",
            "ALTER TABLE sessions ADD COLUMN total_tonnage_kg REAL",
            "ALTER TABLE sessions ADD COLUMN best_estimated_1rm_kg REAL",
            "ALTER TABLE sessions ADD COLUMN best_attempt_m REAL",
            "ALTER TABLE rep_records ADD COLUMN swolf_score INTEGER",
            "ALTER TABLE rep_records ADD COLUMN splits_json TEXT NOT NULL DEFAULT '[]'",
        ];
        for sql in alter_statements {
            let _ = self.conn.execute(sql, []);
        }
        Ok(())
    }

    /// Creates a new Template along with its initial `TemplateVersion (v1)` and blocks.
    pub fn create_template(
        &mut self,
        input: &CreateTemplateInput,
        now_ms: i64,
    ) -> Result<TemplateWithVersion, CoreError> {
        let name = input.name.trim();
        if name.is_empty() {
            return Err(CoreError::Validation(
                "Template name cannot be empty".to_string(),
            ));
        }

        let slots = expand_template_slots(input.rounds, &input.blocks)?;
        let is_homogeneous = is_homogeneous_protocol(&slots);
        let total_reps = slots.len() as i32;
        let total_distance_m = compute_total_distance_m(&slots);
        let protocol_hash = compute_protocol_hash(
            input.sport_category,
            input.pool_length_m,
            input.environment,
            input.rounds,
            input.round_rest_ms,
            &input.equipment,
            &input.blocks,
        );

        let template_id = Uuid::now_v7().to_string();
        let version_id = Uuid::now_v7().to_string();
        let equipment_json = serde_json::to_string(&input.equipment)?;

        let tx = self.conn.transaction()?;
        tx.execute(
            r#"
            INSERT INTO templates (
                id, name, sport_category, pool_length_m, environment,
                folder_tag, active_version_id, is_archived, created_at_ms, updated_at_ms
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, 0, ?8, ?8)
            "#,
            params![
                template_id,
                name,
                input.sport_category.as_str(),
                input.pool_length_m,
                input.environment.as_str(),
                input.folder_tag,
                version_id,
                now_ms
            ],
        )?;

        tx.execute(
            r#"
            INSERT INTO template_versions (
                id, template_id, version_number, protocol_hash,
                rounds, round_rest_ms, equipment_json, target_pace_ms_per_100m,
                notes, total_reps, total_distance_m, is_homogeneous, created_at_ms
            ) VALUES (?1, ?2, 1, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)
            "#,
            params![
                version_id,
                template_id,
                protocol_hash,
                input.rounds,
                input.round_rest_ms,
                equipment_json,
                input.target_pace_ms_per_100m,
                input.notes,
                total_reps,
                total_distance_m,
                if is_homogeneous { 1 } else { 0 },
                now_ms
            ],
        )?;

        for (idx, block) in input.blocks.iter().enumerate() {
            let block_id = Uuid::now_v7().to_string();
            tx.execute(
                r#"
                INSERT INTO template_blocks (
                    id, template_version_id, block_order, repeat_count,
                    record_kind, distance_m, stroke_or_movement,
                    rest_mode, rest_or_sendoff_ms, target_duration_ms
                ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)
                "#,
                params![
                    block_id,
                    version_id,
                    idx as i32,
                    block.repeat_count,
                    block.record_kind.as_str(),
                    block.distance_m,
                    block.stroke_or_movement.trim().to_lowercase(),
                    block.rest_mode.as_str(),
                    block.rest_or_sendoff_ms,
                    block.target_duration_ms
                ],
            )?;
        }

        tx.commit()?;
        self.get_template(&template_id)
    }

    /// Updates a Template's protocol.
    /// If the physiological protocol changes (different `protocol_hash`), a new immutable
    /// `TemplateVersion` (`v2`, `v3`, ...) is minted so historical sessions remain bound to their original version.
    pub fn update_template_protocol(
        &mut self,
        input: &UpdateTemplateProtocolInput,
        now_ms: i64,
    ) -> Result<TemplateWithVersion, CoreError> {
        let existing = self.get_template(&input.template_id)?;
        let new_name = input
            .name
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .unwrap_or(&existing.name)
            .to_string();

        let slots = expand_template_slots(input.rounds, &input.blocks)?;
        let is_homogeneous = is_homogeneous_protocol(&slots);
        let total_reps = slots.len() as i32;
        let total_distance_m = compute_total_distance_m(&slots);
        let new_hash = compute_protocol_hash(
            existing.sport_category,
            input.pool_length_m,
            existing.environment,
            input.rounds,
            input.round_rest_ms,
            &input.equipment,
            &input.blocks,
        );

        let tx = self.conn.transaction()?;
        let new_folder = input.folder_tag.clone().or(existing.folder_tag.clone());
        if new_hash == existing.active_version.protocol_hash {
            tx.execute(
                "UPDATE templates SET name = ?1, folder_tag = ?2, updated_at_ms = ?3 WHERE id = ?4",
                params![new_name, new_folder, now_ms, existing.id],
            )?;
            tx.execute(
                "UPDATE template_versions SET target_pace_ms_per_100m = ?1, notes = ?2 WHERE id = ?3",
                params![
                    input.target_pace_ms_per_100m,
                    input.notes,
                    existing.active_version.id
                ],
            )?;
        } else {
            let next_version_num = existing.active_version.version_number + 1;
            let new_version_id = Uuid::now_v7().to_string();
            let equipment_json = serde_json::to_string(&input.equipment)?;

            tx.execute(
                r#"
                INSERT INTO template_versions (
                    id, template_id, version_number, protocol_hash,
                    rounds, round_rest_ms, equipment_json, target_pace_ms_per_100m,
                    notes, total_reps, total_distance_m, is_homogeneous, created_at_ms
                ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13)
                "#,
                params![
                    new_version_id,
                    existing.id,
                    next_version_num,
                    new_hash,
                    input.rounds,
                    input.round_rest_ms,
                    equipment_json,
                    input.target_pace_ms_per_100m,
                    input.notes,
                    total_reps,
                    total_distance_m,
                    if is_homogeneous { 1 } else { 0 },
                    now_ms
                ],
            )?;

            for (idx, block) in input.blocks.iter().enumerate() {
                let block_id = Uuid::now_v7().to_string();
                tx.execute(
                    r#"
                    INSERT INTO template_blocks (
                        id, template_version_id, block_order, repeat_count,
                        record_kind, distance_m, stroke_or_movement,
                        rest_mode, rest_or_sendoff_ms, target_duration_ms
                    ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)
                    "#,
                    params![
                        block_id,
                        new_version_id,
                        idx as i32,
                        block.repeat_count,
                        block.record_kind.as_str(),
                        block.distance_m,
                        block.stroke_or_movement.trim().to_lowercase(),
                        block.rest_mode.as_str(),
                        block.rest_or_sendoff_ms,
                        block.target_duration_ms
                    ],
                )?;
            }

            tx.execute(
                r#"
                UPDATE templates
                SET name = ?1, pool_length_m = ?2, folder_tag = ?3, active_version_id = ?4, updated_at_ms = ?5
                WHERE id = ?6
                "#,
                params![
                    new_name,
                    input.pool_length_m,
                    new_folder,
                    new_version_id,
                    now_ms,
                    existing.id
                ],
            )?;
        }

        tx.commit()?;
        self.get_template(&existing.id)
    }

    /// Archives or unarchives a template without deleting historical sessions.
    pub fn set_template_archived(
        &mut self,
        template_id: &str,
        is_archived: bool,
        now_ms: i64,
    ) -> Result<TemplateWithVersion, CoreError> {
        let changed = self.conn.execute(
            "UPDATE templates SET is_archived = ?1, updated_at_ms = ?2 WHERE id = ?3",
            params![if is_archived { 1 } else { 0 }, now_ms, template_id],
        )?;
        if changed == 0 {
            return Err(CoreError::NotFound(format!(
                "Template not found: {template_id}"
            )));
        }
        self.get_template(template_id)
    }

    /// Lists all protocol versions (`v1..vN`) of a template in descending version order.
    pub fn list_template_versions(
        &self,
        template_id: &str,
    ) -> Result<Vec<TemplateVersion>, CoreError> {
        let mut stmt = self.conn.prepare(
            "SELECT id FROM template_versions WHERE template_id = ?1 ORDER BY version_number DESC",
        )?;
        let ids: Vec<String> = stmt
            .query_map(params![template_id], |r| r.get::<_, String>(0))?
            .collect::<Result<Vec<_>, _>>()?;

        let mut versions = Vec::with_capacity(ids.len());
        for vid in ids {
            versions.push(self.get_template_version(&vid)?);
        }
        Ok(versions)
    }

    /// Loads a `TemplateVersion` along with its ordered `TemplateBlock`s.
    pub fn get_template_version(&self, version_id: &str) -> Result<TemplateVersion, CoreError> {
        let mut stmt = self.conn.prepare(
            r#"
            SELECT id, template_id, version_number, protocol_hash,
                   rounds, round_rest_ms, equipment_json, target_pace_ms_per_100m,
                   notes, total_reps, total_distance_m, is_homogeneous, created_at_ms
            FROM template_versions
            WHERE id = ?1
            "#,
        )?;

        let row = stmt
            .query_row(params![version_id], |r| {
                let eq_json: String = r.get(6)?;
                let eq: Vec<String> = serde_json::from_str(&eq_json).unwrap_or_default();
                let is_hom: i32 = r.get(11)?;
                Ok((
                    r.get::<_, String>(0)?,
                    r.get::<_, String>(1)?,
                    r.get::<_, i32>(2)?,
                    r.get::<_, String>(3)?,
                    r.get::<_, i32>(4)?,
                    r.get::<_, i64>(5)?,
                    eq,
                    r.get::<_, Option<i64>>(7)?,
                    r.get::<_, Option<String>>(8)?,
                    r.get::<_, i32>(9)?,
                    r.get::<_, Option<i32>>(10)?,
                    is_hom != 0,
                    r.get::<_, i64>(12)?,
                ))
            })
            .optional()?
            .ok_or_else(|| {
                CoreError::NotFound(format!("TemplateVersion not found: {version_id}"))
            })?;

        let mut block_stmt = self.conn.prepare(
            r#"
            SELECT id, template_version_id, block_order, repeat_count,
                   record_kind, distance_m, stroke_or_movement,
                   rest_mode, rest_or_sendoff_ms, target_duration_ms
            FROM template_blocks
            WHERE template_version_id = ?1
            ORDER BY block_order ASC
            "#,
        )?;

        let block_rows = block_stmt.query_map(params![version_id], |r| {
            Ok((
                r.get::<_, String>(0)?,
                r.get::<_, String>(1)?,
                r.get::<_, i32>(2)?,
                r.get::<_, i32>(3)?,
                r.get::<_, String>(4)?,
                r.get::<_, Option<i32>>(5)?,
                r.get::<_, String>(6)?,
                r.get::<_, String>(7)?,
                r.get::<_, i64>(8)?,
                r.get::<_, Option<i64>>(9)?,
            ))
        })?;

        let mut blocks = Vec::new();
        for b in block_rows {
            let (id, tv_id, order, count, kind_str, dist, stroke, rest_str, rest_ms, target_ms) =
                b?;
            blocks.push(TemplateBlock {
                id,
                template_version_id: tv_id,
                block_order: order,
                repeat_count: count,
                record_kind: RecordKind::from_db(&kind_str)?,
                distance_m: dist,
                stroke_or_movement: stroke,
                rest_mode: RestMode::from_db(&rest_str)?,
                rest_or_sendoff_ms: rest_ms,
                target_duration_ms: target_ms,
            });
        }

        Ok(TemplateVersion {
            id: row.0,
            template_id: row.1,
            version_number: row.2,
            protocol_hash: row.3,
            rounds: row.4,
            round_rest_ms: row.5,
            equipment: row.6,
            target_pace_ms_per_100m: row.7,
            notes: row.8,
            total_reps: row.9,
            total_distance_m: row.10,
            is_homogeneous: row.11,
            blocks,
            created_at_ms: row.12,
        })
    }

    /// Expands a stored `TemplateVersion` into its deterministic sequence of `ExpectedRepSlot`s.
    pub fn expand_version_slots(
        &self,
        version_id: &str,
    ) -> Result<Vec<ExpectedRepSlot>, CoreError> {
        let ver = self.get_template_version(version_id)?;
        let block_inputs: Vec<TemplateBlockInput> = ver
            .blocks
            .iter()
            .map(|b| TemplateBlockInput {
                repeat_count: b.repeat_count,
                record_kind: b.record_kind,
                distance_m: b.distance_m,
                stroke_or_movement: b.stroke_or_movement.clone(),
                rest_mode: b.rest_mode,
                rest_or_sendoff_ms: b.rest_or_sendoff_ms,
                target_duration_ms: b.target_duration_ms,
            })
            .collect();
        expand_template_slots(ver.rounds, &block_inputs)
    }

    /// Retrieves a `TemplateWithVersion` by ID.
    pub fn get_template(&self, template_id: &str) -> Result<TemplateWithVersion, CoreError> {
        let row = self
            .conn
            .query_row(
                r#"
                SELECT t.id, t.name, t.sport_category, t.pool_length_m, t.environment,
                       t.folder_tag, t.active_version_id, t.is_archived, t.created_at_ms, t.updated_at_ms,
                       (SELECT COUNT(*) FROM sessions s WHERE s.template_id = t.id)
                FROM templates t
                WHERE t.id = ?1
                "#,
                params![template_id],
                |r| {
                    Ok((
                        r.get::<_, String>(0)?,
                        r.get::<_, String>(1)?,
                        r.get::<_, String>(2)?,
                        r.get::<_, Option<i32>>(3)?,
                        r.get::<_, String>(4)?,
                        r.get::<_, Option<String>>(5)?,
                        r.get::<_, String>(6)?,
                        r.get::<_, i32>(7)? != 0,
                        r.get::<_, i64>(8)?,
                        r.get::<_, i64>(9)?,
                        r.get::<_, i32>(10)?,
                    ))
                },
            )
            .optional()?
            .ok_or_else(|| CoreError::NotFound(format!("Template not found: {template_id}")))?;

        let active_version = self.get_template_version(&row.6)?;
        Ok(TemplateWithVersion {
            id: row.0,
            name: row.1,
            sport_category: SportCategory::from_db(&row.2)?,
            pool_length_m: row.3,
            environment: EnvironmentType::from_db(&row.4)?,
            folder_tag: row.5,
            is_archived: row.7,
            active_version,
            total_sessions_count: row.10,
            created_at_ms: row.8,
            updated_at_ms: row.9,
        })
    }

    /// Lists all active templates ordered by most recently updated.
    pub fn list_templates(&self) -> Result<Vec<TemplateWithVersion>, CoreError> {
        self.list_templates_filtered(false)
    }

    /// Lists templates, optionally including archived ones.
    pub fn list_templates_filtered(
        &self,
        include_archived: bool,
    ) -> Result<Vec<TemplateWithVersion>, CoreError> {
        let sql = if include_archived {
            "SELECT id FROM templates ORDER BY is_archived ASC, updated_at_ms DESC"
        } else {
            "SELECT id FROM templates WHERE is_archived = 0 ORDER BY updated_at_ms DESC"
        };
        let mut stmt = self.conn.prepare(sql)?;
        let ids: Vec<String> = stmt
            .query_map([], |r| r.get::<_, String>(0))?
            .collect::<Result<Vec<_>, _>>()?;

        let mut list = Vec::with_capacity(ids.len());
        for id in ids {
            list.push(self.get_template(&id)?);
        }
        Ok(list)
    }

    /// Logs a completed session for a template version, computing deterministic rep and session metrics.
    pub fn log_session(
        &mut self,
        input: &LogSessionInput,
        now_ms: i64,
    ) -> Result<SessionWithReps, CoreError> {
        let template = self.get_template(&input.template_id)?;
        let version_id = input
            .template_version_id
            .as_deref()
            .unwrap_or(&template.active_version.id);
        let version = self.get_template_version(version_id)?;
        if version.template_id != template.id {
            return Err(CoreError::Validation(
                "TemplateVersion does not belong to the specified Template".to_string(),
            ));
        }

        let slots = self.expand_version_slots(version_id)?;
        let slot_map: HashMap<i32, &ExpectedRepSlot> =
            slots.iter().map(|s| (s.slot_index, s)).collect();

        if input.reps.is_empty() {
            return Err(CoreError::Validation(
                "Session must include at least one rep record".to_string(),
            ));
        }

        let session_id = Uuid::now_v7().to_string();
        let mut built_reps = Vec::with_capacity(input.reps.len());

        for rep_in in &input.reps {
            let slot = slot_map.get(&rep_in.slot_index).ok_or_else(|| {
                CoreError::Validation(format!(
                    "Invalid slot_index {} for template version (1..={})",
                    rep_in.slot_index,
                    slots.len()
                ))
            })?;

            if !rep_in.is_skipped {
                if let Some(dur) = rep_in.duration_ms {
                    if dur <= 0 {
                        return Err(CoreError::Validation(format!(
                            "Rep slot {} duration_ms must be > 0",
                            rep_in.slot_index
                        )));
                    }
                }
            }

            let pace_ms_per_100m = match (rep_in.duration_ms, slot.distance_m, rep_in.is_skipped) {
                (Some(dur), Some(dist), false) => compute_pace_ms_per_100m(dur, dist),
                _ => None,
            };

            let actual_rest_ms = if rep_in.is_skipped {
                None
            } else {
                compute_actual_rest_ms(slot.rest_mode, slot.rest_or_sendoff_ms, rep_in.duration_ms)
            };

            let swolf_score = if rep_in.is_skipped {
                None
            } else {
                compute_swolf_score(rep_in.duration_ms, rep_in.stroke_count)
            };

            built_reps.push(RepRecord {
                id: Uuid::now_v7().to_string(),
                session_id: session_id.clone(),
                slot_index: slot.slot_index,
                round_index: slot.round_index,
                block_order: slot.block_order,
                distance_m: slot.distance_m,
                duration_ms: rep_in.duration_ms,
                pace_ms_per_100m,
                actual_rest_ms,
                stroke_count: rep_in.stroke_count,
                swolf_score,
                rpe: rep_in.rpe,
                weight_kg: rep_in.weight_kg,
                reps_completed: rep_in.reps_completed,
                attempt_result_m: rep_in.attempt_result_m,
                splits_ms: rep_in.splits_ms.clone(),
                is_skipped: rep_in.is_skipped,
                notes: rep_in.notes.clone(),
            });
        }

        built_reps.sort_by_key(|r| r.slot_index);
        let metrics = compute_session_metrics(&slots, &built_reps, version.is_homogeneous);
        let pool_length_m = input.pool_length_m.or(template.pool_length_m);

        let tx = self.conn.transaction()?;
        tx.execute(
            r#"
            INSERT INTO sessions (
                id, template_id, template_version_id, workout_id,
                exported_external_uuid, performed_at_ms, pool_length_m,
                is_completed, notes,
                total_active_duration_ms, avg_duration_ms,
                best_rep_duration_ms, worst_rep_duration_ms,
                avg_pace_ms_per_100m, std_dev_ms, consistency_cv_pct,
                fatigue_index_pct, total_tonnage_kg, best_estimated_1rm_kg,
                best_attempt_m, created_at_ms
            ) VALUES (
                ?1, ?2, ?3, ?4, NULL, ?5, ?6, 1, ?7,
                ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19
            )
            "#,
            params![
                session_id,
                template.id,
                version.id,
                input.workout_id,
                input.performed_at_ms,
                pool_length_m,
                input.notes,
                metrics.total_active_duration_ms,
                metrics.avg_duration_ms,
                metrics.best_rep_duration_ms,
                metrics.worst_rep_duration_ms,
                metrics.avg_pace_ms_per_100m,
                metrics.std_dev_ms,
                metrics.consistency_cv_pct,
                metrics.fatigue_index_pct,
                metrics.total_tonnage_kg,
                metrics.best_estimated_1rm_kg,
                metrics.best_attempt_m,
                now_ms
            ],
        )?;

        for rep in &built_reps {
            let splits_json = serde_json::to_string(&rep.splits_ms)?;
            tx.execute(
                r#"
                INSERT INTO rep_records (
                    id, session_id, slot_index, round_index, block_order,
                    distance_m, duration_ms, pace_ms_per_100m, actual_rest_ms,
                    stroke_count, swolf_score, rpe, weight_kg, reps_completed,
                    attempt_result_m, splits_json, is_skipped, notes
                ) VALUES (
                    ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9,
                    ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18
                )
                "#,
                params![
                    rep.id,
                    rep.session_id,
                    rep.slot_index,
                    rep.round_index,
                    rep.block_order,
                    rep.distance_m,
                    rep.duration_ms,
                    rep.pace_ms_per_100m,
                    rep.actual_rest_ms,
                    rep.stroke_count,
                    rep.swolf_score,
                    rep.rpe,
                    rep.weight_kg,
                    rep.reps_completed,
                    rep.attempt_result_m,
                    splits_json,
                    if rep.is_skipped { 1 } else { 0 },
                    rep.notes
                ],
            )?;
        }

        tx.commit()?;
        self.get_session(&session_id)
    }

    /// Deletes a session and its repetitions.
    pub fn delete_session(&mut self, session_id: &str) -> Result<bool, CoreError> {
        let deleted = self
            .conn
            .execute("DELETE FROM sessions WHERE id = ?1", params![session_id])?;
        Ok(deleted > 0)
    }

    /// Links (or unlinks when `workout_id` is `None`) an existing session to an imported workout.
    pub fn link_session_to_workout(
        &mut self,
        session_id: &str,
        workout_id: Option<&str>,
    ) -> Result<SessionWithReps, CoreError> {
        if let Some(wid) = workout_id {
            let _ = self.get_workout(wid)?;
        }
        let changed = self.conn.execute(
            "UPDATE sessions SET workout_id = ?1 WHERE id = ?2",
            params![workout_id, session_id],
        )?;
        if changed == 0 {
            return Err(CoreError::NotFound(format!(
                "Session not found: {session_id}"
            )));
        }
        self.get_session(session_id)
    }

    /// Marks a session as exported to Apple HealthKit (`HKWorkout`) or Health Connect,
    /// preventing duplicate exports of the same session.
    pub fn mark_session_exported(
        &mut self,
        session_id: &str,
        external_uuid: &str,
    ) -> Result<SessionWithReps, CoreError> {
        let existing = self.get_session(session_id)?;
        if let Some(already) = existing.exported_external_uuid {
            return Err(CoreError::DuplicateExternalWorkout(format!(
                "Session {session_id} is already exported as {already}"
            )));
        }
        self.conn.execute(
            "UPDATE sessions SET exported_external_uuid = ?1 WHERE id = ?2",
            params![external_uuid, session_id],
        )?;
        self.get_session(session_id)
    }

    /// Retrieves a single `SessionWithReps` by ID.
    pub fn get_session(&self, session_id: &str) -> Result<SessionWithReps, CoreError> {
        let row = self
            .conn
            .query_row(
                r#"
                SELECT s.id, s.template_id, t.name, s.template_version_id,
                       tv.version_number, tv.protocol_hash, tv.is_homogeneous,
                       s.workout_id, s.exported_external_uuid,
                       s.performed_at_ms, s.pool_length_m,
                       s.is_completed, s.notes,
                       s.total_active_duration_ms, s.avg_duration_ms,
                       s.best_rep_duration_ms, s.worst_rep_duration_ms,
                       s.avg_pace_ms_per_100m, s.std_dev_ms,
                       s.consistency_cv_pct, s.fatigue_index_pct,
                       s.total_tonnage_kg, s.best_estimated_1rm_kg, s.best_attempt_m,
                       s.created_at_ms
                FROM sessions s
                JOIN templates t ON t.id = s.template_id
                JOIN template_versions tv ON tv.id = s.template_version_id
                WHERE s.id = ?1
                "#,
                params![session_id],
                |r| {
                    Ok((
                        r.get::<_, String>(0)?,
                        r.get::<_, String>(1)?,
                        r.get::<_, String>(2)?,
                        r.get::<_, String>(3)?,
                        r.get::<_, i32>(4)?,
                        r.get::<_, String>(5)?,
                        r.get::<_, i32>(6)? != 0,
                        r.get::<_, Option<String>>(7)?,
                        r.get::<_, Option<String>>(8)?,
                        r.get::<_, i64>(9)?,
                        r.get::<_, Option<i32>>(10)?,
                        r.get::<_, i32>(11)? != 0,
                        r.get::<_, Option<String>>(12)?,
                        SessionSummaryMetrics {
                            total_active_duration_ms: r.get(13)?,
                            avg_duration_ms: r.get(14)?,
                            best_rep_duration_ms: r.get(15)?,
                            worst_rep_duration_ms: r.get(16)?,
                            avg_pace_ms_per_100m: r.get(17)?,
                            std_dev_ms: r.get(18)?,
                            consistency_cv_pct: r.get(19)?,
                            fatigue_index_pct: r.get(20)?,
                            total_tonnage_kg: r.get(21)?,
                            best_estimated_1rm_kg: r.get(22)?,
                            best_attempt_m: r.get(23)?,
                        },
                        r.get::<_, i64>(24)?,
                    ))
                },
            )
            .optional()?
            .ok_or_else(|| CoreError::NotFound(format!("Session not found: {session_id}")))?;

        let mut rep_stmt = self.conn.prepare(
            r#"
            SELECT id, session_id, slot_index, round_index, block_order,
                   distance_m, duration_ms, pace_ms_per_100m, actual_rest_ms,
                   stroke_count, swolf_score, rpe, weight_kg, reps_completed,
                   attempt_result_m, splits_json, is_skipped, notes
            FROM rep_records
            WHERE session_id = ?1
            ORDER BY slot_index ASC
            "#,
        )?;

        let reps = rep_stmt
            .query_map(params![session_id], |r| {
                let splits_str: String = r.get(15)?;
                let splits_ms: Vec<i64> = serde_json::from_str(&splits_str).unwrap_or_default();
                Ok(RepRecord {
                    id: r.get(0)?,
                    session_id: r.get(1)?,
                    slot_index: r.get(2)?,
                    round_index: r.get(3)?,
                    block_order: r.get(4)?,
                    distance_m: r.get(5)?,
                    duration_ms: r.get(6)?,
                    pace_ms_per_100m: r.get(7)?,
                    actual_rest_ms: r.get(8)?,
                    stroke_count: r.get(9)?,
                    swolf_score: r.get(10)?,
                    rpe: r.get(11)?,
                    weight_kg: r.get(12)?,
                    reps_completed: r.get(13)?,
                    attempt_result_m: r.get(14)?,
                    splits_ms,
                    is_skipped: r.get::<_, i32>(16)? != 0,
                    notes: r.get(17)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(SessionWithReps {
            id: row.0,
            template_id: row.1,
            template_name: row.2,
            template_version_id: row.3,
            template_version_number: row.4,
            protocol_hash: row.5,
            is_homogeneous: row.6,
            workout_id: row.7,
            exported_external_uuid: row.8,
            performed_at_ms: row.9,
            pool_length_m: row.10,
            is_completed: row.11,
            notes: row.12,
            metrics: row.13,
            reps,
            created_at_ms: row.14,
        })
    }

    /// Lists sessions for a given template ordered by `performed_at_ms DESC`.
    pub fn list_sessions_for_template(
        &self,
        template_id: &str,
    ) -> Result<Vec<SessionWithReps>, CoreError> {
        let mut stmt = self.conn.prepare(
            "SELECT id FROM sessions WHERE template_id = ?1 ORDER BY performed_at_ms DESC, created_at_ms DESC",
        )?;
        let ids: Vec<String> = stmt
            .query_map(params![template_id], |r| r.get::<_, String>(0))?
            .collect::<Result<Vec<_>, _>>()?;

        let mut sessions = Vec::with_capacity(ids.len());
        for id in ids {
            sessions.push(self.get_session(&id)?);
        }
        Ok(sessions)
    }

    /// Lists all sessions across all templates ordered by `performed_at_ms DESC`.
    pub fn list_all_sessions(&self) -> Result<Vec<SessionWithReps>, CoreError> {
        let mut stmt = self
            .conn
            .prepare("SELECT id FROM sessions ORDER BY performed_at_ms DESC, created_at_ms DESC")?;
        let ids: Vec<String> = stmt
            .query_map([], |r| r.get::<_, String>(0))?
            .collect::<Result<Vec<_>, _>>()?;

        let mut sessions = Vec::with_capacity(ids.len());
        for id in ids {
            sessions.push(self.get_session(&id)?);
        }
        Ok(sessions)
    }

    /// Generates the full `TemplateAnalyticsReport` for a template.
    pub fn get_template_analytics(
        &self,
        template_id: &str,
    ) -> Result<TemplateAnalyticsReport, CoreError> {
        let template = self.get_template(template_id)?;
        let sessions = self.list_sessions_for_template(template_id)?;
        let snapshots = self.list_health_snapshots()?;
        Ok(compute_template_analytics(&template, &sessions, &snapshots))
    }

    /// Imports an Apple HealthKit (`HKWorkout`), Health Connect, or manual workout.
    pub fn import_workout(
        &mut self,
        input: &ImportWorkoutInput,
        now_ms: i64,
    ) -> Result<Workout, CoreError> {
        if let Some(ext_uuid) = input.external_source_uuid.as_deref() {
            let exists: Option<String> = self
                .conn
                .query_row(
                    "SELECT id FROM workouts WHERE external_source_uuid = ?1",
                    params![ext_uuid],
                    |r| r.get(0),
                )
                .optional()?;
            if exists.is_some() {
                return Err(CoreError::DuplicateExternalWorkout(ext_uuid.to_string()));
            }
        }

        let id = Uuid::now_v7().to_string();
        let laps_json = serde_json::to_string(&input.lap_durations_ms)?;
        self.conn.execute(
            r#"
            INSERT INTO workouts (
                id, sport_category, source_type, external_source_uuid,
                external_source_name, started_at_ms, ended_at_ms,
                duration_ms, total_distance_m, pool_length_m,
                active_energy_kcal, avg_heart_rate_bpm, max_heart_rate_bpm,
                has_route, route_summary, kept_as_standalone,
                lap_durations_json, notes, created_at_ms
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, 0, ?16, ?17, ?18)
            "#,
            params![
                id,
                input.sport_category.as_str(),
                input.source_type.as_str(),
                input.external_source_uuid,
                input.external_source_name,
                input.started_at_ms,
                input.ended_at_ms,
                input.duration_ms,
                input.total_distance_m,
                input.pool_length_m,
                input.active_energy_kcal,
                input.avg_heart_rate_bpm,
                input.max_heart_rate_bpm,
                if input.has_route { 1 } else { 0 },
                input.route_summary,
                laps_json,
                input.notes,
                now_ms
            ],
        )?;

        self.get_workout(&id)
    }

    /// Marks an imported workout as explicitly kept as a general standalone record (Step 7 of Import Flow).
    pub fn set_workout_standalone(
        &mut self,
        workout_id: &str,
        kept_as_standalone: bool,
    ) -> Result<Workout, CoreError> {
        let changed = self.conn.execute(
            "UPDATE workouts SET kept_as_standalone = ?1 WHERE id = ?2",
            params![if kept_as_standalone { 1 } else { 0 }, workout_id],
        )?;
        if changed == 0 {
            return Err(CoreError::NotFound(format!(
                "Workout not found: {workout_id}"
            )));
        }
        self.get_workout(workout_id)
    }

    /// Retrieves a workout by ID (including its live `associated_templates_count`).
    pub fn get_workout(&self, workout_id: &str) -> Result<Workout, CoreError> {
        let row = self
            .conn
            .query_row(
                r#"
                SELECT w.id, w.sport_category, w.source_type, w.external_source_uuid,
                       w.external_source_name, w.started_at_ms, w.ended_at_ms,
                       w.duration_ms, w.total_distance_m, w.pool_length_m,
                       w.active_energy_kcal, w.avg_heart_rate_bpm, w.max_heart_rate_bpm,
                       w.has_route, w.route_summary, w.kept_as_standalone,
                       (SELECT COUNT(*) FROM sessions s WHERE s.workout_id = w.id),
                       w.lap_durations_json, w.notes, w.created_at_ms
                FROM workouts w
                WHERE w.id = ?1
                "#,
                params![workout_id],
                |r| {
                    let laps_str: String = r.get(17)?;
                    let laps: Vec<i64> = serde_json::from_str(&laps_str).unwrap_or_default();
                    Ok((
                        r.get::<_, String>(0)?,
                        r.get::<_, String>(1)?,
                        r.get::<_, String>(2)?,
                        r.get::<_, Option<String>>(3)?,
                        r.get::<_, Option<String>>(4)?,
                        r.get::<_, i64>(5)?,
                        r.get::<_, Option<i64>>(6)?,
                        r.get::<_, Option<i64>>(7)?,
                        r.get::<_, Option<f64>>(8)?,
                        r.get::<_, Option<i32>>(9)?,
                        r.get::<_, Option<f64>>(10)?,
                        r.get::<_, Option<f64>>(11)?,
                        r.get::<_, Option<f64>>(12)?,
                        r.get::<_, i32>(13)? != 0,
                        r.get::<_, Option<String>>(14)?,
                        r.get::<_, i32>(15)? != 0,
                        r.get::<_, i32>(16)?,
                        laps,
                        r.get::<_, Option<String>>(18)?,
                        r.get::<_, i64>(19)?,
                    ))
                },
            )
            .optional()?
            .ok_or_else(|| CoreError::NotFound(format!("Workout not found: {workout_id}")))?;

        Ok(Workout {
            id: row.0,
            sport_category: SportCategory::from_db(&row.1)?,
            source_type: WorkoutSourceType::from_db(&row.2)?,
            external_source_uuid: row.3,
            external_source_name: row.4,
            started_at_ms: row.5,
            ended_at_ms: row.6,
            duration_ms: row.7,
            total_distance_m: row.8,
            pool_length_m: row.9,
            active_energy_kcal: row.10,
            avg_heart_rate_bpm: row.11,
            max_heart_rate_bpm: row.12,
            has_route: row.13,
            route_summary: row.14,
            kept_as_standalone: row.15,
            associated_templates_count: row.16,
            lap_durations_ms: row.17,
            notes: row.18,
            created_at_ms: row.19,
        })
    }

    /// v1.2: Deterministically pre-fills `RepInput` records for a `TemplateVersion` using
    /// recorded `HKWorkoutEvent` lap segments (`workout.lap_durations_ms`).
    /// When a slot's distance is a multiple of `pool_length_m` (e.g., a 100m or 150m slot in a 50m pool),
    /// consecutive 50m watch laps are summed into `duration_ms` and preserved in `splits_ms`.
    pub fn prefill_reps_from_workout_laps(
        &self,
        workout_id: &str,
        template_version_id: &str,
    ) -> Result<Vec<RepInput>, CoreError> {
        let workout = self.get_workout(workout_id)?;
        let slots = self.expand_version_slots(template_version_id)?;
        if workout.lap_durations_ms.is_empty() {
            return Ok(Vec::new());
        }

        let pool_len = workout.pool_length_m.unwrap_or(50).max(25);
        let mut lap_cursor = 0usize;
        let mut prefilled = Vec::new();

        for slot in &slots {
            if lap_cursor >= workout.lap_durations_ms.len() {
                break;
            }
            let slot_dist = slot.distance_m.unwrap_or(pool_len).max(pool_len);
            let laps_needed = ((slot_dist + (pool_len / 2)) / pool_len).max(1) as usize;
            if lap_cursor + laps_needed > workout.lap_durations_ms.len() {
                break;
            }

            let slice = &workout.lap_durations_ms[lap_cursor..lap_cursor + laps_needed];
            let total_dur: i64 = slice.iter().sum();
            let splits = if laps_needed > 1 {
                slice.to_vec()
            } else {
                Vec::new()
            };

            prefilled.push(RepInput {
                slot_index: slot.slot_index,
                duration_ms: Some(total_dur),
                stroke_count: None,
                rpe: None,
                weight_kg: None,
                reps_completed: None,
                attempt_result_m: None,
                splits_ms: splits,
                is_skipped: false,
                notes: Some("Auto-prefilled from Apple Watch lap events".to_string()),
            });
            lap_cursor += laps_needed;
        }

        Ok(prefilled)
    }

    /// Lists all imported or manual workouts ordered by `started_at_ms DESC`.
    pub fn list_workouts(&self) -> Result<Vec<Workout>, CoreError> {
        let mut stmt = self
            .conn
            .prepare("SELECT id FROM workouts ORDER BY started_at_ms DESC")?;
        let ids: Vec<String> = stmt
            .query_map([], |r| r.get::<_, String>(0))?
            .collect::<Result<Vec<_>, _>>()?;

        let mut list = Vec::with_capacity(ids.len());
        for id in ids {
            list.push(self.get_workout(&id)?);
        }
        Ok(list)
    }

    /// Runs the deterministic template matcher for a stored workout.
    pub fn match_templates_for_workout(
        &self,
        workout_id: &str,
    ) -> Result<Vec<TemplateMatchCandidate>, CoreError> {
        let workout = self.get_workout(workout_id)?;
        let templates = self.list_templates()?;
        let all_sessions = self.list_all_sessions()?;
        let linked_sessions: Vec<SessionWithReps> = all_sessions
            .into_iter()
            .filter(|s| s.workout_id.as_deref() == Some(workout_id))
            .collect();

        Ok(match_workout_to_templates(
            &workout,
            &templates,
            &linked_sessions,
        ))
    }

    /// Inserts or updates a daily health snapshot (`YYYY-MM-DD`).
    pub fn upsert_health_snapshot(
        &mut self,
        snapshot: &DailyHealthSnapshot,
    ) -> Result<DailyHealthSnapshot, CoreError> {
        if snapshot.date_iso.trim().len() != 10 {
            return Err(CoreError::Validation(
                "date_iso must follow YYYY-MM-DD format".to_string(),
            ));
        }

        self.conn.execute(
            r#"
            INSERT INTO daily_health_snapshots (
                date_iso, sleep_duration_minutes, hrv_sdnn_ms,
                resting_hr_bpm, vo2_max_ml_kg_min, source_summary, captured_at_ms
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
            ON CONFLICT(date_iso) DO UPDATE SET
                sleep_duration_minutes = excluded.sleep_duration_minutes,
                hrv_sdnn_ms = excluded.hrv_sdnn_ms,
                resting_hr_bpm = excluded.resting_hr_bpm,
                vo2_max_ml_kg_min = excluded.vo2_max_ml_kg_min,
                source_summary = excluded.source_summary,
                captured_at_ms = excluded.captured_at_ms
            "#,
            params![
                snapshot.date_iso,
                snapshot.sleep_duration_minutes,
                snapshot.hrv_sdnn_ms,
                snapshot.resting_hr_bpm,
                snapshot.vo2_max_ml_kg_min,
                snapshot.source_summary,
                snapshot.captured_at_ms
            ],
        )?;

        Ok(snapshot.clone())
    }

    /// Lists all stored daily health snapshots ordered by `date_iso DESC`.
    pub fn list_health_snapshots(&self) -> Result<Vec<DailyHealthSnapshot>, CoreError> {
        let mut stmt = self.conn.prepare(
            r#"
            SELECT date_iso, sleep_duration_minutes, hrv_sdnn_ms,
                   resting_hr_bpm, vo2_max_ml_kg_min, source_summary, captured_at_ms
            FROM daily_health_snapshots
            ORDER BY date_iso DESC
            "#,
        )?;

        let rows = stmt
            .query_map([], |r| {
                Ok(DailyHealthSnapshot {
                    date_iso: r.get(0)?,
                    sleep_duration_minutes: r.get(1)?,
                    hrv_sdnn_ms: r.get(2)?,
                    resting_hr_bpm: r.get(3)?,
                    vo2_max_ml_kg_min: r.get(4)?,
                    source_summary: r.get(5)?,
                    captured_at_ms: r.get(6)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(rows)
    }

    /// Computes the deterministic `HealthContextSummary` (Screen 7 — Health Context & Bevel Rings).
    pub fn get_health_context_summary(&self) -> Result<HealthContextSummary, CoreError> {
        let snapshots = self.list_health_snapshots()?;
        Ok(compute_health_context_summary(&snapshots))
    }

    /// Reads the persisted `AppSettings` (Multi-Theme preset, default pool length, preferred sport).
    pub fn get_app_settings(&self) -> Result<AppSettings, CoreError> {
        let row = self.conn.query_row(
            r#"
            SELECT active_theme, default_pool_length_m, preferred_sport,
                   haptics_enabled, auto_advance_sendoff, updated_at_ms
            FROM app_settings
            WHERE singleton_id = 1
            "#,
            [],
            |r| {
                Ok((
                    r.get::<_, String>(0)?,
                    r.get::<_, i32>(1)?,
                    r.get::<_, String>(2)?,
                    r.get::<_, i32>(3)? != 0,
                    r.get::<_, i32>(4)? != 0,
                    r.get::<_, i64>(5)?,
                ))
            },
        )?;

        Ok(AppSettings {
            active_theme: ThemePreset::from_db(&row.0)?,
            default_pool_length_m: row.1,
            preferred_sport: SportCategory::from_db(&row.2)?,
            haptics_enabled: row.3,
            auto_advance_sendoff: row.4,
            updated_at_ms: row.5,
        })
    }

    /// Updates the persisted `AppSettings` in SQLite.
    pub fn update_app_settings(
        &mut self,
        settings: &AppSettings,
    ) -> Result<AppSettings, CoreError> {
        self.conn.execute(
            r#"
            UPDATE app_settings
            SET active_theme = ?1,
                default_pool_length_m = ?2,
                preferred_sport = ?3,
                haptics_enabled = ?4,
                auto_advance_sendoff = ?5,
                updated_at_ms = ?6
            WHERE singleton_id = 1
            "#,
            params![
                settings.active_theme.as_str(),
                settings.default_pool_length_m,
                settings.preferred_sport.as_str(),
                if settings.haptics_enabled { 1 } else { 0 },
                if settings.auto_advance_sendoff { 1 } else { 0 },
                settings.updated_at_ms
            ],
        )?;
        self.get_app_settings()
    }

    /// Builds the unified `DailyTrainingTimeline` for a specific date (`YYYY-MM-DD`).
    pub fn get_daily_timeline(&self, date_iso: &str) -> Result<DailyTrainingTimeline, CoreError> {
        let workouts: Vec<Workout> = self
            .list_workouts()?
            .into_iter()
            .filter(|w| epoch_ms_to_date_iso(w.started_at_ms) == date_iso)
            .collect();

        let sessions: Vec<SessionWithReps> = self
            .list_all_sessions()?
            .into_iter()
            .filter(|s| epoch_ms_to_date_iso(s.performed_at_ms) == date_iso)
            .collect();

        let workout_ids_on_day: std::collections::HashSet<&str> =
            workouts.iter().map(|w| w.id.as_str()).collect();

        let workout_distance_m: f64 = workouts.iter().filter_map(|w| w.total_distance_m).sum();

        let standalone_session_distance_m: f64 = sessions
            .iter()
            .filter(|s| {
                s.workout_id
                    .as_deref()
                    .map(|wid| !workout_ids_on_day.contains(wid))
                    .unwrap_or(true)
            })
            .map(|s| {
                s.reps
                    .iter()
                    .filter(|r| !r.is_skipped)
                    .filter_map(|r| r.distance_m.map(|d| d as f64))
                    .sum::<f64>()
            })
            .sum();

        let workout_duration_ms: i64 = workouts.iter().filter_map(|w| w.duration_ms).sum();
        let standalone_duration_ms: i64 = sessions
            .iter()
            .filter(|s| {
                s.workout_id
                    .as_deref()
                    .map(|wid| !workout_ids_on_day.contains(wid))
                    .unwrap_or(true)
            })
            .map(|s| s.metrics.total_active_duration_ms)
            .sum();

        let health_snapshot = self
            .list_health_snapshots()?
            .into_iter()
            .find(|h| h.date_iso == date_iso);

        Ok(DailyTrainingTimeline {
            date_iso: date_iso.to_string(),
            workouts,
            standalone_and_linked_sessions: sessions,
            total_volume_distance_m: workout_distance_m + standalone_session_distance_m,
            total_duration_ms: workout_duration_ms + standalone_duration_ms,
            health_snapshot,
        })
    }

    /// Exports the entire local database into a portable, deterministic JSON backup string.
    pub fn export_backup_json(&self, exported_at_ms: i64) -> Result<String, CoreError> {
        let templates = self.list_templates_filtered(true)?;
        let mut all_template_versions = Vec::new();
        for tpl in &templates {
            let mut versions = self.list_template_versions(&tpl.id)?;
            versions.reverse(); // chronological v1..vN
            all_template_versions.extend(versions);
        }
        let payload = DatabaseBackupPayload {
            schema_version: 2,
            exported_at_ms,
            templates,
            all_template_versions,
            workouts: self.list_workouts()?,
            sessions: self.list_all_sessions()?,
            health_snapshots: self.list_health_snapshots()?,
        };
        Ok(serde_json::to_string_pretty(&payload)?)
    }

    /// Restores a portable JSON backup (`DatabaseBackupPayload`) idempotently into the local SQLite database.
    /// Enforces fail-closed size and item count bounds before opening any transaction.
    pub fn import_backup_json(&mut self, backup_json: &str) -> Result<RestoreBackupResult, CoreError> {
        const MAX_BACKUP_BYTES: usize = 33_554_432; // 32 MiB
        const MAX_BACKUP_TEMPLATES: usize = 10_000;
        const MAX_BACKUP_SESSIONS: usize = 100_000;

        if backup_json.len() > MAX_BACKUP_BYTES {
            return Err(CoreError::Validation(format!(
                "Backup payload exceeds 32 MiB limit ({} bytes)",
                backup_json.len()
            )));
        }

        let payload: DatabaseBackupPayload = serde_json::from_str(backup_json)?;
        if payload.schema_version < 1 || payload.schema_version > 4 {
            return Err(CoreError::Validation(format!(
                "Unsupported backup schema_version: {}",
                payload.schema_version
            )));
        }
        if payload.templates.len() > MAX_BACKUP_TEMPLATES {
            return Err(CoreError::Validation(format!(
                "Backup templates count ({}) exceeds limit ({MAX_BACKUP_TEMPLATES})",
                payload.templates.len()
            )));
        }
        if payload.sessions.len() > MAX_BACKUP_SESSIONS {
            return Err(CoreError::Validation(format!(
                "Backup sessions count ({}) exceeds limit ({MAX_BACKUP_SESSIONS})",
                payload.sessions.len()
            )));
        }

        let tx = self.conn.transaction()?;
        let mut templates_restored = 0usize;
        let mut workouts_restored = 0usize;
        let mut sessions_restored = 0usize;
        let mut health_snapshots_restored = 0usize;

        for tpl in &payload.templates {
            let exists: Option<String> = tx
                .query_row(
                    "SELECT id FROM templates WHERE id = ?1",
                    params![tpl.id],
                    |r| r.get(0),
                )
                .optional()?;
            if exists.is_none() {
                tx.execute(
                    r#"
                    INSERT INTO templates (
                        id, name, sport_category, pool_length_m, environment,
                        folder_tag, active_version_id, is_archived, created_at_ms, updated_at_ms
                    ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)
                    "#,
                    params![
                        tpl.id,
                        tpl.name,
                        tpl.sport_category.as_str(),
                        tpl.pool_length_m,
                        tpl.environment.as_str(),
                        tpl.folder_tag,
                        tpl.active_version.id,
                        if tpl.is_archived { 1 } else { 0 },
                        tpl.created_at_ms,
                        tpl.updated_at_ms
                    ],
                )?;
                templates_restored += 1;
            }

            let ver = &tpl.active_version;
            let ver_exists: Option<String> = tx
                .query_row(
                    "SELECT id FROM template_versions WHERE id = ?1",
                    params![ver.id],
                    |r| r.get(0),
                )
                .optional()?;
            if ver_exists.is_none() {
                let eq_json = serde_json::to_string(&ver.equipment)?;
                tx.execute(
                    r#"
                    INSERT INTO template_versions (
                        id, template_id, version_number, protocol_hash,
                        rounds, round_rest_ms, equipment_json, target_pace_ms_per_100m,
                        notes, total_reps, total_distance_m, is_homogeneous, created_at_ms
                    ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13)
                    "#,
                    params![
                        ver.id,
                        ver.template_id,
                        ver.version_number,
                        ver.protocol_hash,
                        ver.rounds,
                        ver.round_rest_ms,
                        eq_json,
                        ver.target_pace_ms_per_100m,
                        ver.notes,
                        ver.total_reps,
                        ver.total_distance_m,
                        if ver.is_homogeneous { 1 } else { 0 },
                        ver.created_at_ms
                    ],
                )?;

                for b in &ver.blocks {
                    tx.execute(
                        r#"
                        INSERT OR IGNORE INTO template_blocks (
                            id, template_version_id, block_order, repeat_count,
                            record_kind, distance_m, stroke_or_movement,
                            rest_mode, rest_or_sendoff_ms, target_duration_ms
                        ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)
                        "#,
                        params![
                            b.id,
                            b.template_version_id,
                            b.block_order,
                            b.repeat_count,
                            b.record_kind.as_str(),
                            b.distance_m,
                            b.stroke_or_movement,
                            b.rest_mode.as_str(),
                            b.rest_or_sendoff_ms,
                            b.target_duration_ms
                        ],
                    )?;
                }
            }
        }

        // Restore any additional historical TemplateVersions (v1..vN) so sessions referencing old versions satisfy FK constraints
        for ver in &payload.all_template_versions {
            let ver_exists: Option<String> = tx
                .query_row(
                    "SELECT id FROM template_versions WHERE id = ?1",
                    params![ver.id],
                    |r| r.get(0),
                )
                .optional()?;
            if ver_exists.is_none() {
                let eq_json = serde_json::to_string(&ver.equipment)?;
                tx.execute(
                    r#"
                    INSERT INTO template_versions (
                        id, template_id, version_number, protocol_hash,
                        rounds, round_rest_ms, equipment_json, target_pace_ms_per_100m,
                        notes, total_reps, total_distance_m, is_homogeneous, created_at_ms
                    ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13)
                    "#,
                    params![
                        ver.id,
                        ver.template_id,
                        ver.version_number,
                        ver.protocol_hash,
                        ver.rounds,
                        ver.round_rest_ms,
                        eq_json,
                        ver.target_pace_ms_per_100m,
                        ver.notes,
                        ver.total_reps,
                        ver.total_distance_m,
                        if ver.is_homogeneous { 1 } else { 0 },
                        ver.created_at_ms
                    ],
                )?;

                for b in &ver.blocks {
                    tx.execute(
                        r#"
                        INSERT OR IGNORE INTO template_blocks (
                            id, template_version_id, block_order, repeat_count,
                            record_kind, distance_m, stroke_or_movement,
                            rest_mode, rest_or_sendoff_ms, target_duration_ms
                        ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)
                        "#,
                        params![
                            b.id,
                            b.template_version_id,
                            b.block_order,
                            b.repeat_count,
                            b.record_kind.as_str(),
                            b.distance_m,
                            b.stroke_or_movement,
                            b.rest_mode.as_str(),
                            b.rest_or_sendoff_ms,
                            b.target_duration_ms
                        ],
                    )?;
                }
            }
        }

        for w in &payload.workouts {
            let inserted = tx.execute(
                r#"
                INSERT OR IGNORE INTO workouts (
                    id, sport_category, source_type, external_source_uuid,
                    external_source_name, started_at_ms, ended_at_ms,
                    duration_ms, total_distance_m, pool_length_m,
                    active_energy_kcal, avg_heart_rate_bpm, max_heart_rate_bpm,
                    notes, created_at_ms
                ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15)
                "#,
                params![
                    w.id,
                    w.sport_category.as_str(),
                    w.source_type.as_str(),
                    w.external_source_uuid,
                    w.external_source_name,
                    w.started_at_ms,
                    w.ended_at_ms,
                    w.duration_ms,
                    w.total_distance_m,
                    w.pool_length_m,
                    w.active_energy_kcal,
                    w.avg_heart_rate_bpm,
                    w.max_heart_rate_bpm,
                    w.notes,
                    w.created_at_ms
                ],
            )?;
            if inserted > 0 {
                workouts_restored += 1;
            }
        }

        for s in &payload.sessions {
            let s_exists: Option<String> = tx
                .query_row(
                    "SELECT id FROM sessions WHERE id = ?1",
                    params![s.id],
                    |r| r.get(0),
                )
                .optional()?;
            if s_exists.is_none() {
                tx.execute(
                    r#"
                    INSERT INTO sessions (
                        id, template_id, template_version_id, workout_id,
                        exported_external_uuid, performed_at_ms, pool_length_m,
                        is_completed, notes,
                        total_active_duration_ms, avg_duration_ms,
                        best_rep_duration_ms, worst_rep_duration_ms,
                        avg_pace_ms_per_100m, std_dev_ms, consistency_cv_pct,
                        fatigue_index_pct, total_tonnage_kg, best_estimated_1rm_kg,
                        best_attempt_m, created_at_ms
                    ) VALUES (
                        ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9,
                        ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20, ?21
                    )
                    "#,
                    params![
                        s.id,
                        s.template_id,
                        s.template_version_id,
                        s.workout_id,
                        s.exported_external_uuid,
                        s.performed_at_ms,
                        s.pool_length_m,
                        if s.is_completed { 1 } else { 0 },
                        s.notes,
                        s.metrics.total_active_duration_ms,
                        s.metrics.avg_duration_ms,
                        s.metrics.best_rep_duration_ms,
                        s.metrics.worst_rep_duration_ms,
                        s.metrics.avg_pace_ms_per_100m,
                        s.metrics.std_dev_ms,
                        s.metrics.consistency_cv_pct,
                        s.metrics.fatigue_index_pct,
                        s.metrics.total_tonnage_kg,
                        s.metrics.best_estimated_1rm_kg,
                        s.metrics.best_attempt_m,
                        s.created_at_ms
                    ],
                )?;

                for r in &s.reps {
                    let splits_json = serde_json::to_string(&r.splits_ms)?;
                    tx.execute(
                        r#"
                        INSERT OR IGNORE INTO rep_records (
                            id, session_id, slot_index, round_index, block_order,
                            distance_m, duration_ms, pace_ms_per_100m, actual_rest_ms,
                            stroke_count, swolf_score, rpe, weight_kg, reps_completed,
                            attempt_result_m, splits_json, is_skipped, notes
                        ) VALUES (
                            ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9,
                            ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18
                        )
                        "#,
                        params![
                            r.id,
                            r.session_id,
                            r.slot_index,
                            r.round_index,
                            r.block_order,
                            r.distance_m,
                            r.duration_ms,
                            r.pace_ms_per_100m,
                            r.actual_rest_ms,
                            r.stroke_count,
                            r.swolf_score,
                            r.rpe,
                            r.weight_kg,
                            r.reps_completed,
                            r.attempt_result_m,
                            splits_json,
                            if r.is_skipped { 1 } else { 0 },
                            r.notes
                        ],
                    )?;
                }
                sessions_restored += 1;
            }
        }

        for h in &payload.health_snapshots {
            tx.execute(
                r#"
                INSERT OR REPLACE INTO daily_health_snapshots (
                    date_iso, sleep_duration_minutes, hrv_sdnn_ms,
                    resting_hr_bpm, vo2_max_ml_kg_min, source_summary, captured_at_ms
                ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
                "#,
                params![
                    h.date_iso,
                    h.sleep_duration_minutes,
                    h.hrv_sdnn_ms,
                    h.resting_hr_bpm,
                    h.vo2_max_ml_kg_min,
                    h.source_summary,
                    h.captured_at_ms
                ],
            )?;
            health_snapshots_restored += 1;
        }

        tx.commit()?;
        Ok(RestoreBackupResult {
            templates_restored,
            workouts_restored,
            sessions_restored,
            health_snapshots_restored,
        })
    }

    /// Exports all logged sessions and repetitions as a flat CSV table for external analysis.
    pub fn export_sessions_csv(&self) -> Result<String, CoreError> {
        let sessions = self.list_all_sessions()?;
        let mut csv = String::from(
            "session_id,date_iso,template_name,template_version,slot_index,round_index,distance_m,duration_ms,pace_ms_per_100m,actual_rest_ms,stroke_count,swolf_score,weight_kg,reps_completed,attempt_result_m,is_skipped\n",
        );

        for s in sessions {
            let date_iso = epoch_ms_to_date_iso(s.performed_at_ms);
            let safe_name = s.template_name.replace(',', " ");
            for r in s.reps {
                csv.push_str(&format!(
                    "{},{},{},v{},{},{},{},{},{},{},{},{},{},{},{},{}\n",
                    s.id,
                    date_iso,
                    safe_name,
                    s.template_version_number,
                    r.slot_index,
                    r.round_index,
                    r.distance_m.map(|v| v.to_string()).unwrap_or_default(),
                    r.duration_ms.map(|v| v.to_string()).unwrap_or_default(),
                    r.pace_ms_per_100m
                        .map(|v| v.to_string())
                        .unwrap_or_default(),
                    r.actual_rest_ms.map(|v| v.to_string()).unwrap_or_default(),
                    r.stroke_count.map(|v| v.to_string()).unwrap_or_default(),
                    r.swolf_score.map(|v| v.to_string()).unwrap_or_default(),
                    r.weight_kg
                        .map(|v| format!("{v:.1}"))
                        .unwrap_or_default(),
                    r.reps_completed
                        .map(|v| v.to_string())
                        .unwrap_or_default(),
                    r.attempt_result_m
                        .map(|v| format!("{v:.2}"))
                        .unwrap_or_default(),
                    r.is_skipped
                ));
            }
        }
        Ok(csv)
    }

    /// Returns diagnostic counts of all tables in the local SQLite database.
    pub fn get_database_diagnostics(&self) -> Result<DatabaseDiagnostics, CoreError> {
        let count_of = |table: &str| -> Result<i32, CoreError> {
            Ok(self
                .conn
                .query_row(&format!("SELECT COUNT(*) FROM {table}"), [], |r| r.get(0))?)
        };
        Ok(DatabaseDiagnostics {
            engine_version: "1.3.0".to_string(),
            schema_version: 4,
            templates_count: count_of("templates")?,
            template_versions_count: count_of("template_versions")?,
            sessions_count: count_of("sessions")?,
            rep_records_count: count_of("rep_records")?,
            workouts_count: count_of("workouts")?,
            health_snapshots_count: count_of("daily_health_snapshots")?,
        })
    }

    /// Seeds realistic multi-sport templates (Finswimming, Swimming, Track, Gym), sessions,
    /// and Apple Health data when the database is empty.
    pub fn seed_demo_data_if_empty(&mut self) -> Result<bool, CoreError> {
        let count: i32 = self
            .conn
            .query_row("SELECT COUNT(*) FROM templates", [], |r| r.get(0))?;
        if count > 0 {
            return Ok(false);
        }

        let nov_15_2026_ms: i64 = 1_794_751_200_000; // 2026-11-15
        let nov_22_2026_ms: i64 = 1_795_356_000_000; // 2026-11-22

        // 1. Homogeneous Finswimming Template: 8 × 50m Surface Monofin — 30s Rest
        let tpl_surface = self.create_template(
            &CreateTemplateInput {
                name: "8×50m Surface Monofin — 30s Rest".to_string(),
                sport_category: SportCategory::Finswimming,
                pool_length_m: Some(50),
                environment: EnvironmentType::Pool,
                folder_tag: Some("Race Pace / Taper".to_string()),
                rounds: 1,
                round_rest_ms: 0,
                equipment: vec!["monofin".to_string(), "snorkel".to_string()],
                target_pace_ms_per_100m: Some(36_400),
                notes: Some("Race-pace surface protocol from Lane 4.".to_string()),
                blocks: vec![TemplateBlockInput {
                    repeat_count: 8,
                    record_kind: RecordKind::TimedDistance,
                    distance_m: Some(50),
                    stroke_or_movement: "surface".to_string(),
                    rest_mode: RestMode::FixedRest,
                    rest_or_sendoff_ms: 30_000,
                    target_duration_ms: Some(18_200),
                }],
            },
            nov_15_2026_ms,
        )?;

        // 2. Pyramid Template: 50-100-150-100-50m Speed Pyramid (Bifins)
        let tpl_pyramid = self.create_template(
            &CreateTemplateInput {
                name: "50-100-150-100-50m Speed Pyramid (Bifins)".to_string(),
                sport_category: SportCategory::Finswimming,
                pool_length_m: Some(50),
                environment: EnvironmentType::Pool,
                folder_tag: Some("Lactate Tolerance".to_string()),
                rounds: 1,
                round_rest_ms: 0,
                equipment: vec!["bifins".to_string(), "snorkel".to_string()],
                target_pace_ms_per_100m: Some(44_000),
                notes: Some("Lactate tolerance pyramid with symmetric descend.".to_string()),
                blocks: vec![
                    TemplateBlockInput {
                        repeat_count: 1,
                        record_kind: RecordKind::TimedDistance,
                        distance_m: Some(50),
                        stroke_or_movement: "bifins".to_string(),
                        rest_mode: RestMode::FixedRest,
                        rest_or_sendoff_ms: 20_000,
                        target_duration_ms: Some(21_500),
                    },
                    TemplateBlockInput {
                        repeat_count: 1,
                        record_kind: RecordKind::TimedDistance,
                        distance_m: Some(100),
                        stroke_or_movement: "bifins".to_string(),
                        rest_mode: RestMode::FixedRest,
                        rest_or_sendoff_ms: 30_000,
                        target_duration_ms: Some(44_000),
                    },
                    TemplateBlockInput {
                        repeat_count: 1,
                        record_kind: RecordKind::TimedDistance,
                        distance_m: Some(150),
                        stroke_or_movement: "bifins".to_string(),
                        rest_mode: RestMode::FixedRest,
                        rest_or_sendoff_ms: 45_000,
                        target_duration_ms: Some(67_500),
                    },
                    TemplateBlockInput {
                        repeat_count: 1,
                        record_kind: RecordKind::TimedDistance,
                        distance_m: Some(100),
                        stroke_or_movement: "bifins".to_string(),
                        rest_mode: RestMode::FixedRest,
                        rest_or_sendoff_ms: 30_000,
                        target_duration_ms: Some(43_800),
                    },
                    TemplateBlockInput {
                        repeat_count: 1,
                        record_kind: RecordKind::TimedDistance,
                        distance_m: Some(50),
                        stroke_or_movement: "bifins".to_string(),
                        rest_mode: RestMode::FixedRest,
                        rest_or_sendoff_ms: 20_000,
                        target_duration_ms: Some(21_000),
                    },
                ],
            },
            nov_15_2026_ms,
        )?;

        // 3. Compound Rounds Template: 4 × [2×50m @ 0:50 + 1×100m @ 1:40] Freestyle Send-Off
        let _tpl_compound = self.create_template(
            &CreateTemplateInput {
                name: "4 × [2×50m @ 0:50 + 1×100m @ 1:40] Send-Off".to_string(),
                sport_category: SportCategory::Swimming,
                pool_length_m: Some(50),
                environment: EnvironmentType::Pool,
                folder_tag: Some("Aerobic Threshold".to_string()),
                rounds: 4,
                round_rest_ms: 30_000,
                equipment: vec!["paddles".to_string()],
                target_pace_ms_per_100m: Some(64_000),
                notes: Some("Aerobic threshold compound rounds on send-off cycle.".to_string()),
                blocks: vec![
                    TemplateBlockInput {
                        repeat_count: 2,
                        record_kind: RecordKind::TimedDistance,
                        distance_m: Some(50),
                        stroke_or_movement: "freestyle".to_string(),
                        rest_mode: RestMode::SendOff,
                        rest_or_sendoff_ms: 50_000,
                        target_duration_ms: Some(31_500),
                    },
                    TemplateBlockInput {
                        repeat_count: 1,
                        record_kind: RecordKind::TimedDistance,
                        distance_m: Some(100),
                        stroke_or_movement: "freestyle".to_string(),
                        rest_mode: RestMode::SendOff,
                        rest_or_sendoff_ms: 100_000,
                        target_duration_ms: Some(64_000),
                    },
                ],
            },
            nov_15_2026_ms,
        )?;

        // 4. Overview Section 3 Example B: 6 × 100m — 60s Rest
        let _tpl_ex_b = self.create_template(
            &CreateTemplateInput {
                name: "6×100m Freestyle — 60s Rest".to_string(),
                sport_category: SportCategory::Swimming,
                pool_length_m: Some(50),
                environment: EnvironmentType::Pool,
                folder_tag: Some("VO2 Max / Pace".to_string()),
                rounds: 1,
                round_rest_ms: 0,
                equipment: vec![],
                target_pace_ms_per_100m: Some(62_000),
                notes: Some("Overview Example B: 6×100m with 60s recovery.".to_string()),
                blocks: vec![TemplateBlockInput {
                    repeat_count: 6,
                    record_kind: RecordKind::TimedDistance,
                    distance_m: Some(100),
                    stroke_or_movement: "freestyle".to_string(),
                    rest_mode: RestMode::FixedRest,
                    rest_or_sendoff_ms: 60_000,
                    target_duration_ms: Some(62_000),
                }],
            },
            nov_15_2026_ms,
        )?;

        // 5. Overview Section 3 Example C: 6 × 100m — 30s Rest (Distinct protocol from B due to 30s rest!)
        let _tpl_ex_c = self.create_template(
            &CreateTemplateInput {
                name: "6×100m Freestyle — 30s Rest".to_string(),
                sport_category: SportCategory::Swimming,
                pool_length_m: Some(50),
                environment: EnvironmentType::Pool,
                folder_tag: Some("Aerobic Threshold".to_string()),
                rounds: 1,
                round_rest_ms: 0,
                equipment: vec![],
                target_pace_ms_per_100m: Some(64_500),
                notes: Some("Overview Example C: 6×100m with short 30s rest (distinct protocol from 60s rest).".to_string()),
                blocks: vec![TemplateBlockInput {
                    repeat_count: 6,
                    record_kind: RecordKind::TimedDistance,
                    distance_m: Some(100),
                    stroke_or_movement: "freestyle".to_string(),
                    rest_mode: RestMode::FixedRest,
                    rest_or_sendoff_ms: 30_000,
                    target_duration_ms: Some(64_500),
                }],
            },
            nov_15_2026_ms,
        )?;

        // Seed Apple Watch Imported Workout on Nov 22, 2026 (including recorded 50m lap events!)
        let apple_workout = self.import_workout(
            &ImportWorkoutInput {
                sport_category: SportCategory::Swimming,
                source_type: WorkoutSourceType::AppleHealth,
                external_source_uuid: Some("HK-ULTRA2-2026-11-22-POOL50".to_string()),
                external_source_name: Some("Apple Watch Ultra 2".to_string()),
                started_at_ms: nov_22_2026_ms,
                ended_at_ms: Some(nov_22_2026_ms + 2_538_000),
                duration_ms: Some(2_538_000),
                total_distance_m: Some(2400.0),
                pool_length_m: Some(50),
                active_energy_kcal: Some(612.0),
                avg_heart_rate_bpm: Some(154.0),
                max_heart_rate_bpm: Some(182.0),
                has_route: false,
                route_summary: None,
                lap_durations_ms: vec![
                    18_200, 18_350, 18_400, 18_300, 18_250, 18_300, 18_150, 17_950,
                ],
                notes: Some("Afternoon pool workout imported from Apple HealthKit.".to_string()),
            },
            nov_22_2026_ms,
        )?;

        // Log Session 1 (Nov 15 baseline) for 8×50m Surface Monofin
        let s1_times = [
            19_100, 19_250, 19_400, 19_300, 19_500, 19_600, 19_450, 19_200,
        ];
        self.log_session(
            &LogSessionInput {
                template_id: tpl_surface.id.clone(),
                template_version_id: None,
                workout_id: None,
                performed_at_ms: nov_15_2026_ms,
                pool_length_m: Some(50),
                notes: Some("Baseline session — solid underwater dolphin kick.".to_string()),
                reps: s1_times
                    .iter()
                    .enumerate()
                    .map(|(i, &ms)| RepInput {
                        slot_index: (i + 1) as i32,
                        duration_ms: Some(ms),
                        stroke_count: Some(14),
                        rpe: Some(8),
                        weight_kg: None,
                        reps_completed: None,
                        attempt_result_m: None,
                        splits_ms: vec![],
                        is_skipped: false,
                        notes: None,
                    })
                    .collect(),
            },
            nov_15_2026_ms,
        )?;

        // Log Session 2 (Nov 22 improved execution, linked to Apple Watch workout)
        let s2_times = [
            18_200, 18_350, 18_400, 18_300, 18_250, 18_300, 18_150, 17_950,
        ];
        self.log_session(
            &LogSessionInput {
                template_id: tpl_surface.id.clone(),
                template_version_id: None,
                workout_id: Some(apple_workout.id.clone()),
                performed_at_ms: nov_22_2026_ms,
                pool_length_m: Some(50),
                notes: Some("Negative split finish on Rep 8 (17.95s PB).".to_string()),
                reps: s2_times
                    .iter()
                    .enumerate()
                    .map(|(i, &ms)| RepInput {
                        slot_index: (i + 1) as i32,
                        duration_ms: Some(ms),
                        stroke_count: Some(13),
                        rpe: Some(8),
                        weight_kg: None,
                        reps_completed: None,
                        attempt_result_m: None,
                        splits_ms: vec![],
                        is_skipped: false,
                        notes: None,
                    })
                    .collect(),
            },
            nov_22_2026_ms,
        )?;

        // Log 2 Pyramid Sessions (Nov 15 vs Nov 22)
        let pyr_s1 = [22_100, 45_400, 69_200, 45_800, 22_300];
        self.log_session(
            &LogSessionInput {
                template_id: tpl_pyramid.id.clone(),
                template_version_id: None,
                workout_id: None,
                performed_at_ms: nov_15_2026_ms + 1_800_000,
                pool_length_m: Some(50),
                notes: Some("First pyramid execution.".to_string()),
                reps: pyr_s1
                    .iter()
                    .enumerate()
                    .map(|(i, &ms)| RepInput {
                        slot_index: (i + 1) as i32,
                        duration_ms: Some(ms),
                        stroke_count: None,
                        rpe: Some(9),
                        weight_kg: None,
                        reps_completed: None,
                        attempt_result_m: None,
                        splits_ms: vec![],
                        is_skipped: false,
                        notes: None,
                    })
                    .collect(),
            },
            nov_15_2026_ms + 1_800_000,
        )?;

        let pyr_s2 = [21_400, 43_900, 66_800, 43_700, 20_950];
        self.log_session(
            &LogSessionInput {
                template_id: tpl_pyramid.id.clone(),
                template_version_id: None,
                workout_id: Some(apple_workout.id),
                performed_at_ms: nov_22_2026_ms + 1_200_000,
                pool_length_m: Some(50),
                notes: Some("Strong 150m peak and fast final 50m.".to_string()),
                reps: pyr_s2
                    .iter()
                    .enumerate()
                    .map(|(i, &ms)| RepInput {
                        slot_index: (i + 1) as i32,
                        duration_ms: Some(ms),
                        stroke_count: None,
                        rpe: Some(9),
                        weight_kg: None,
                        reps_completed: None,
                        attempt_result_m: None,
                        splits_ms: vec![],
                        is_skipped: false,
                        notes: None,
                    })
                    .collect(),
            },
            nov_22_2026_ms + 1_200_000,
        )?;

        // Seed Health Snapshots for Nov 15 & Nov 22
        self.upsert_health_snapshot(&DailyHealthSnapshot {
            date_iso: epoch_ms_to_date_iso(nov_15_2026_ms),
            sleep_duration_minutes: Some(425),
            hrv_sdnn_ms: Some(58.4),
            resting_hr_bpm: Some(53.0),
            vo2_max_ml_kg_min: Some(61.2),
            source_summary: Some("Apple Health (Apple Watch Ultra 2)".to_string()),
            captured_at_ms: nov_15_2026_ms,
        })?;

        self.upsert_health_snapshot(&DailyHealthSnapshot {
            date_iso: epoch_ms_to_date_iso(nov_22_2026_ms),
            sleep_duration_minutes: Some(490),
            hrv_sdnn_ms: Some(74.2),
            resting_hr_bpm: Some(48.0),
            vo2_max_ml_kg_min: Some(62.0),
            source_summary: Some("Apple Health (Apple Watch Ultra 2)".to_string()),
            captured_at_ms: nov_22_2026_ms,
        })?;

        Ok(true)
    }
}
