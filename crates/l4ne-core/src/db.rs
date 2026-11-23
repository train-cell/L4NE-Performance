//! SQLite Storage Engine for `l4ne-core` (`l4ne_core::db`).
//!
//! Implements local-first persistence, template protocol versioning, session logging,
//! HealthKit workout deduplication, daily training timeline aggregation, and JSON/CSV export.

use crate::analytics::{
    compute_actual_rest_ms, compute_pace_ms_per_100m, compute_session_metrics,
    compute_template_analytics, epoch_ms_to_date_iso,
};
use crate::engine::{
    compute_protocol_hash, compute_total_distance_m, expand_template_slots,
    is_homogeneous_protocol,
};
use crate::matcher::match_workout_to_templates;
use crate::models::{
    CoreError, CreateTemplateInput, DailyHealthSnapshot, DailyTrainingTimeline,
    DatabaseBackupPayload, EnvironmentType, ExpectedRepSlot, ImportWorkoutInput, LogSessionInput,
    RecordKind, RepInput, RepRecord, RestMode, SessionSummaryMetrics, SessionWithReps,
    SportCategory, TemplateAnalyticsReport, TemplateBlock, TemplateBlockInput,
    TemplateMatchCandidate, TemplateVersion, TemplateWithVersion, UpdateTemplateProtocolInput,
    Workout, WorkoutSourceType,
};
use rusqlite::{params, Connection, OptionalExtension};
use std::collections::HashMap;
use uuid::Uuid;

pub struct L4neDatabase {
    conn: Connection,
}

impl L4neDatabase {
    /// Opens or creates a SQLite database at the given file path (or `":memory:"`) and runs schema migrations.
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

    /// Runs idempotent DDL migrations for the L4NE Training schema.
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
                notes TEXT,
                created_at_ms INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY NOT NULL,
                template_id TEXT NOT NULL REFERENCES templates(id) ON DELETE RESTRICT,
                template_version_id TEXT NOT NULL REFERENCES template_versions(id) ON DELETE RESTRICT,
                workout_id TEXT REFERENCES workouts(id) ON DELETE SET NULL,
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
                rpe INTEGER,
                weight_kg REAL,
                reps_completed INTEGER,
                attempt_result_m REAL,
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
                active_version_id, is_archived, created_at_ms, updated_at_ms
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, 0, ?7, ?7)
            "#,
            params![
                template_id,
                name,
                input.sport_category.as_str(),
                input.pool_length_m,
                input.environment.as_str(),
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
        if new_hash == existing.active_version.protocol_hash {
            // Protocol is physiologically identical: update non-structural metadata only
            tx.execute(
                "UPDATE templates SET name = ?1, updated_at_ms = ?2 WHERE id = ?3",
                params![new_name, now_ms, existing.id],
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
            // Mint new TemplateVersion (v + 1) to preserve historical integrity
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
                SET name = ?1, pool_length_m = ?2, active_version_id = ?3, updated_at_ms = ?4
                WHERE id = ?5
                "#,
                params![
                    new_name,
                    input.pool_length_m,
                    new_version_id,
                    now_ms,
                    existing.id
                ],
            )?;
        }

        tx.commit()?;
        self.get_template(&existing.id)
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
                       t.active_version_id, t.is_archived, t.created_at_ms, t.updated_at_ms,
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
                        r.get::<_, String>(5)?,
                        r.get::<_, i32>(6)? != 0,
                        r.get::<_, i64>(7)?,
                        r.get::<_, i64>(8)?,
                        r.get::<_, i32>(9)?,
                    ))
                },
            )
            .optional()?
            .ok_or_else(|| CoreError::NotFound(format!("Template not found: {template_id}")))?;

        let active_version = self.get_template_version(&row.5)?;
        Ok(TemplateWithVersion {
            id: row.0,
            name: row.1,
            sport_category: SportCategory::from_db(&row.2)?,
            pool_length_m: row.3,
            environment: EnvironmentType::from_db(&row.4)?,
            is_archived: row.6,
            active_version,
            total_sessions_count: row.9,
            created_at_ms: row.7,
            updated_at_ms: row.8,
        })
    }

    /// Lists all templates ordered by most recently updated.
    pub fn list_templates(&self) -> Result<Vec<TemplateWithVersion>, CoreError> {
        let mut stmt = self
            .conn
            .prepare("SELECT id FROM templates WHERE is_archived = 0 ORDER BY updated_at_ms DESC")?;
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
                rpe: rep_in.rpe,
                weight_kg: rep_in.weight_kg,
                reps_completed: rep_in.reps_completed,
                attempt_result_m: rep_in.attempt_result_m,
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
                performed_at_ms, pool_length_m, is_completed, notes,
                total_active_duration_ms, avg_duration_ms,
                best_rep_duration_ms, worst_rep_duration_ms,
                avg_pace_ms_per_100m, std_dev_ms, consistency_cv_pct,
                fatigue_index_pct, created_at_ms
            ) VALUES (
                ?1, ?2, ?3, ?4, ?5, ?6, 1, ?7,
                ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16
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
                now_ms
            ],
        )?;

        for rep in &built_reps {
            tx.execute(
                r#"
                INSERT INTO rep_records (
                    id, session_id, slot_index, round_index, block_order,
                    distance_m, duration_ms, pace_ms_per_100m, actual_rest_ms,
                    stroke_count, rpe, weight_kg, reps_completed,
                    attempt_result_m, is_skipped, notes
                ) VALUES (
                    ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9,
                    ?10, ?11, ?12, ?13, ?14, ?15, ?16
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
                    rep.rpe,
                    rep.weight_kg,
                    rep.reps_completed,
                    rep.attempt_result_m,
                    if rep.is_skipped { 1 } else { 0 },
                    rep.notes
                ],
            )?;
        }

        tx.commit()?;
        self.get_session(&session_id)
    }

    /// Retrieves a single `SessionWithReps` by ID.
    pub fn get_session(&self, session_id: &str) -> Result<SessionWithReps, CoreError> {
        let row = self
            .conn
            .query_row(
                r#"
                SELECT s.id, s.template_id, t.name, s.template_version_id,
                       tv.version_number, tv.protocol_hash, tv.is_homogeneous,
                       s.workout_id, s.performed_at_ms, s.pool_length_m,
                       s.is_completed, s.notes,
                       s.total_active_duration_ms, s.avg_duration_ms,
                       s.best_rep_duration_ms, s.worst_rep_duration_ms,
                       s.avg_pace_ms_per_100m, s.std_dev_ms,
                       s.consistency_cv_pct, s.fatigue_index_pct, s.created_at_ms
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
                        r.get::<_, i64>(8)?,
                        r.get::<_, Option<i32>>(9)?,
                        r.get::<_, i32>(10)? != 0,
                        r.get::<_, Option<String>>(11)?,
                        SessionSummaryMetrics {
                            total_active_duration_ms: r.get(12)?,
                            avg_duration_ms: r.get(13)?,
                            best_rep_duration_ms: r.get(14)?,
                            worst_rep_duration_ms: r.get(15)?,
                            avg_pace_ms_per_100m: r.get(16)?,
                            std_dev_ms: r.get(17)?,
                            consistency_cv_pct: r.get(18)?,
                            fatigue_index_pct: r.get(19)?,
                        },
                        r.get::<_, i64>(20)?,
                    ))
                },
            )
            .optional()?
            .ok_or_else(|| CoreError::NotFound(format!("Session not found: {session_id}")))?;

        let mut rep_stmt = self.conn.prepare(
            r#"
            SELECT id, session_id, slot_index, round_index, block_order,
                   distance_m, duration_ms, pace_ms_per_100m, actual_rest_ms,
                   stroke_count, rpe, weight_kg, reps_completed,
                   attempt_result_m, is_skipped, notes
            FROM rep_records
            WHERE session_id = ?1
            ORDER BY slot_index ASC
            "#,
        )?;

        let reps = rep_stmt
            .query_map(params![session_id], |r| {
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
                    rpe: r.get(10)?,
                    weight_kg: r.get(11)?,
                    reps_completed: r.get(12)?,
                    attempt_result_m: r.get(13)?,
                    is_skipped: r.get::<_, i32>(14)? != 0,
                    notes: r.get(15)?,
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
            performed_at_ms: row.8,
            pool_length_m: row.9,
            is_completed: row.10,
            notes: row.11,
            metrics: row.12,
            reps,
            created_at_ms: row.13,
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
    /// Prevents duplicate imports using `external_source_uuid`.
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
        self.conn.execute(
            r#"
            INSERT INTO workouts (
                id, sport_category, source_type, external_source_uuid,
                external_source_name, started_at_ms, ended_at_ms,
                duration_ms, total_distance_m, pool_length_m,
                active_energy_kcal, avg_heart_rate_bpm, max_heart_rate_bpm,
                notes, created_at_ms
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15)
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
                input.notes,
                now_ms
            ],
        )?;

        self.get_workout(&id)
    }

    /// Retrieves a workout by ID.
    pub fn get_workout(&self, workout_id: &str) -> Result<Workout, CoreError> {
        let row = self
            .conn
            .query_row(
                r#"
                SELECT id, sport_category, source_type, external_source_uuid,
                       external_source_name, started_at_ms, ended_at_ms,
                       duration_ms, total_distance_m, pool_length_m,
                       active_energy_kcal, avg_heart_rate_bpm, max_heart_rate_bpm,
                       notes, created_at_ms
                FROM workouts
                WHERE id = ?1
                "#,
                params![workout_id],
                |r| {
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
                        r.get::<_, Option<String>>(13)?,
                        r.get::<_, i64>(14)?,
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
            notes: row.13,
            created_at_ms: row.14,
        })
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

    /// Builds the unified `DailyTrainingTimeline` for a specific date (`YYYY-MM-DD`).
    /// Prevents double-counting volume when a template session is linked to a parent Apple Watch workout.
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

        // Total distance = sum of workouts on that day + sum of standalone sessions (not linked to any workout on that day)
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
        let payload = DatabaseBackupPayload {
            schema_version: 1,
            exported_at_ms,
            templates: self.list_templates()?,
            workouts: self.list_workouts()?,
            sessions: self.list_all_sessions()?,
            health_snapshots: self.list_health_snapshots()?,
        };
        Ok(serde_json::to_string_pretty(&payload)?)
    }

    /// Exports all logged sessions and repetitions as a flat CSV table for external analysis.
    pub fn export_sessions_csv(&self) -> Result<String, CoreError> {
        let sessions = self.list_all_sessions()?;
        let mut csv = String::from(
            "session_id,date_iso,template_name,template_version,slot_index,round_index,distance_m,duration_ms,pace_ms_per_100m,actual_rest_ms,is_skipped\n",
        );

        for s in sessions {
            let date_iso = epoch_ms_to_date_iso(s.performed_at_ms);
            let safe_name = s.template_name.replace(',', " ");
            for r in s.reps {
                csv.push_str(&format!(
                    "{},{},{},v{},{},{},{},{},{},{},{}\n",
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
                    r.is_skipped
                ));
            }
        }
        Ok(csv)
    }

    /// Seeds realistic Swimming & Finswimming templates, sessions, and Apple Health data
    /// when the database is empty.
    pub fn seed_demo_data_if_empty(&mut self) -> Result<bool, CoreError> {
        let count: i32 = self
            .conn
            .query_row("SELECT COUNT(*) FROM templates", [], |r| r.get(0))?;
        if count > 0 {
            return Ok(false);
        }

        // Fixed deterministic timestamps (Nov 2026)
        let nov_15_2026_ms: i64 = 1_794_751_200_000; // 2026-11-15
        let nov_22_2026_ms: i64 = 1_795_356_000_000; // 2026-11-22

        // 1. Homogeneous Finswimming Template: 8 × 50m Surface Monofin — 30s Rest
        let tpl_surface = self.create_template(
            &CreateTemplateInput {
                name: "8×50m Surface Monofin — 30s Rest".to_string(),
                sport_category: SportCategory::Finswimming,
                pool_length_m: Some(50),
                environment: EnvironmentType::Pool,
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

        // Seed Apple Watch Imported Workout on Nov 22, 2026
        let apple_workout = self.import_workout(
            &ImportWorkoutInput {
                sport_category: SportCategory::Swimming,
                source_type: WorkoutSourceType::AppleHealth,
                external_source_uuid: Some("HK-ULTRA2-2026-11-22-POOL50".to_string()),
                external_source_name: Some("Apple Watch Ultra 2".to_string()),
                started_at_ms: nov_22_2026_ms,
                ended_at_ms: Some(nov_22_2026_ms + 2_538_000),
                duration_ms: Some(2_538_000), // 42m 18s
                total_distance_m: Some(2400.0),
                pool_length_m: Some(50),
                active_energy_kcal: Some(612.0),
                avg_heart_rate_bpm: Some(154.0),
                max_heart_rate_bpm: Some(182.0),
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
                        stroke_count: None,
                        rpe: Some(8),
                        weight_kg: None,
                        reps_completed: None,
                        attempt_result_m: None,
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
                        stroke_count: None,
                        rpe: Some(8),
                        weight_kg: None,
                        reps_completed: None,
                        attempt_result_m: None,
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
            sleep_duration_minutes: Some(425), // 7h 05m
            hrv_sdnn_ms: Some(58.4),
            resting_hr_bpm: Some(53.0),
            vo2_max_ml_kg_min: Some(61.2),
            source_summary: Some("Apple Health (Apple Watch Ultra 2)".to_string()),
            captured_at_ms: nov_15_2026_ms,
        })?;

        self.upsert_health_snapshot(&DailyHealthSnapshot {
            date_iso: epoch_ms_to_date_iso(nov_22_2026_ms),
            sleep_duration_minutes: Some(490), // 8h 10m
            hrv_sdnn_ms: Some(74.2),
            resting_hr_bpm: Some(48.0),
            vo2_max_ml_kg_min: Some(62.0),
            source_summary: Some("Apple Health (Apple Watch Ultra 2)".to_string()),
            captured_at_ms: nov_22_2026_ms,
        })?;

        Ok(true)
    }
}
