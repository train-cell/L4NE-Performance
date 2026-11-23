//! Core domain models for L4NE Training v1.1 (`l4ne-core`).
//! All time durations are stored in integer milliseconds (`i64`) to guarantee
//! zero floating-point drift in deterministic athletic calculations.

use serde::{Deserialize, Serialize};
use thiserror::Error;

/// Domain errors returned by `l4ne-core`.
#[derive(Debug, Error)]
pub enum CoreError {
    #[error("Database error: {0}")]
    Database(#[from] rusqlite::Error),

    #[error("JSON serialization error: {0}")]
    Serialization(#[from] serde_json::Error),

    #[error("Validation error: {0}")]
    Validation(String),

    #[error("Entity not found: {0}")]
    NotFound(String),

    #[error("Duplicate external workout UUID: {0}")]
    DuplicateExternalWorkout(String),
}

/// Supported sport categories (Multi-sport data model & v1.1 UI).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SportCategory {
    Swimming,
    Finswimming,
    Track,
    Field,
    Gym,
}

impl SportCategory {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Swimming => "swimming",
            Self::Finswimming => "finswimming",
            Self::Track => "track",
            Self::Field => "field",
            Self::Gym => "gym",
        }
    }

    pub fn from_db(value: &str) -> Result<Self, CoreError> {
        match value {
            "swimming" => Ok(Self::Swimming),
            "finswimming" => Ok(Self::Finswimming),
            "track" => Ok(Self::Track),
            "field" => Ok(Self::Field),
            "gym" => Ok(Self::Gym),
            other => Err(CoreError::Validation(format!(
                "Unsupported sport_category: {other}"
            ))),
        }
    }
}

/// Training environment.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EnvironmentType {
    Pool,
    OpenWater,
    Track,
    Gym,
}

impl EnvironmentType {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Pool => "pool",
            Self::OpenWater => "open_water",
            Self::Track => "track",
            Self::Gym => "gym",
        }
    }

    pub fn from_db(value: &str) -> Result<Self, CoreError> {
        match value {
            "pool" => Ok(Self::Pool),
            "open_water" => Ok(Self::OpenWater),
            "track" => Ok(Self::Track),
            "gym" => Ok(Self::Gym),
            other => Err(CoreError::Validation(format!(
                "Unsupported environment: {other}"
            ))),
        }
    }
}

/// Type of measurement recorded for each repetition/attempt.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RecordKind {
    TimedDistance,
    DistanceAttempt,
    WeightReps,
}

impl RecordKind {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::TimedDistance => "timed_distance",
            Self::DistanceAttempt => "distance_attempt",
            Self::WeightReps => "weight_reps",
        }
    }

    pub fn from_db(value: &str) -> Result<Self, CoreError> {
        match value {
            "timed_distance" => Ok(Self::TimedDistance),
            "distance_attempt" => Ok(Self::DistanceAttempt),
            "weight_reps" => Ok(Self::WeightReps),
            other => Err(CoreError::Validation(format!(
                "Unsupported record_kind: {other}"
            ))),
        }
    }
}

/// Rest interval policy between repetitions.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RestMode {
    /// Fixed rest after finishing each repetition (e.g. 30s rest on the wall).
    FixedRest,
    /// Send-off cycle / departure-to-departure interval (e.g. leave every 1:30).
    SendOff,
}

impl RestMode {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::FixedRest => "fixed_rest",
            Self::SendOff => "send_off",
        }
    }

    pub fn from_db(value: &str) -> Result<Self, CoreError> {
        match value {
            "fixed_rest" => Ok(Self::FixedRest),
            "send_off" => Ok(Self::SendOff),
            other => Err(CoreError::Validation(format!(
                "Unsupported rest_mode: {other}"
            ))),
        }
    }
}

/// Data source of a workout record.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum WorkoutSourceType {
    Manual,
    AppleHealth,
    HealthConnect,
}

impl WorkoutSourceType {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Manual => "manual",
            Self::AppleHealth => "apple_health",
            Self::HealthConnect => "health_connect",
        }
    }

    pub fn from_db(value: &str) -> Result<Self, CoreError> {
        match value {
            "manual" => Ok(Self::Manual),
            "apple_health" => Ok(Self::AppleHealth),
            "health_connect" => Ok(Self::HealthConnect),
            other => Err(CoreError::Validation(format!(
                "Unsupported workout source_type: {other}"
            ))),
        }
    }
}

/// Persisted UI Theme Presets (v1.3 Minimalist Graphite / Bevel / Strava Multi-Theme System).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ThemePreset {
    /// Default Minimalist Graphite with Bevel tactile specular cards & L4NE Electric Lime.
    GraphiteBevel,
    /// Strava-inspired Obsidian Slate with Signal Orange (`#FC4C02`) & PR Gold (`#FACC15`).
    StravaObsidian,
    /// LoggedIn-inspired Graphite Navy (`#0F172A` / `#16213A`) with Electric Cyan (`#38BDF8`) & Amber.
    BevelNavy,
    /// High-contrast OLED Pure Carbon (`#07080A`) with Lane 4 Electric Lime (`#CCFF00`).
    Lane4Carbon,
    /// Clean Minimalist Daylight Lab (`#F4F5F7` / `#FFFFFF`) with Deep Graphite typography.
    MinimalAlabaster,
}

impl ThemePreset {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::GraphiteBevel => "graphite_bevel",
            Self::StravaObsidian => "strava_obsidian",
            Self::BevelNavy => "bevel_navy",
            Self::Lane4Carbon => "lane4_carbon",
            Self::MinimalAlabaster => "minimal_alabaster",
        }
    }

    pub fn from_db(value: &str) -> Result<Self, CoreError> {
        match value {
            "graphite_bevel" => Ok(Self::GraphiteBevel),
            "strava_obsidian" => Ok(Self::StravaObsidian),
            "bevel_navy" => Ok(Self::BevelNavy),
            "lane4_carbon" => Ok(Self::Lane4Carbon),
            "minimal_alabaster" => Ok(Self::MinimalAlabaster),
            other => Err(CoreError::Validation(format!(
                "Unsupported theme_preset: {other}"
            ))),
        }
    }
}

/// Persisted local user preferences (stored in `app_settings` table in SQLite Schema v4).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppSettings {
    pub active_theme: ThemePreset,
    pub default_pool_length_m: i32,
    pub preferred_sport: SportCategory,
    pub haptics_enabled: bool,
    pub auto_advance_sendoff: bool,
    pub updated_at_ms: i64,
}

/// Input specification for a block/step inside a template protocol.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TemplateBlockInput {
    pub repeat_count: i32,
    pub record_kind: RecordKind,
    pub distance_m: Option<i32>,
    /// E.g., "surface", "apnea", "immersion", "bifins", "freestyle", "butterfly", "backstroke", "breaststroke", "im", "sprint", "long_jump", "squat"
    pub stroke_or_movement: String,
    pub rest_mode: RestMode,
    pub rest_or_sendoff_ms: i64,
    pub target_duration_ms: Option<i64>,
}

/// Stored block row inside a `TemplateVersion`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TemplateBlock {
    pub id: String,
    pub template_version_id: String,
    pub block_order: i32,
    pub repeat_count: i32,
    pub record_kind: RecordKind,
    pub distance_m: Option<i32>,
    pub stroke_or_movement: String,
    pub rest_mode: RestMode,
    pub rest_or_sendoff_ms: i64,
    pub target_duration_ms: Option<i64>,
}

/// Deterministically expanded expected repetition slot for a `TemplateVersion`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExpectedRepSlot {
    pub slot_index: i32,
    pub round_index: i32,
    pub block_order: i32,
    pub rep_within_block: i32,
    pub record_kind: RecordKind,
    pub distance_m: Option<i32>,
    pub stroke_or_movement: String,
    pub rest_mode: RestMode,
    pub rest_or_sendoff_ms: i64,
    pub target_duration_ms: Option<i64>,
}

/// Input payload for creating a new Template with its initial `TemplateVersion (v1)`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateTemplateInput {
    pub name: String,
    pub sport_category: SportCategory,
    pub pool_length_m: Option<i32>,
    pub environment: EnvironmentType,
    #[serde(default)]
    pub folder_tag: Option<String>,
    pub rounds: i32,
    pub round_rest_ms: i64,
    pub equipment: Vec<String>,
    pub target_pace_ms_per_100m: Option<i64>,
    pub notes: Option<String>,
    pub blocks: Vec<TemplateBlockInput>,
}

/// Input payload for updating a template's protocol.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateTemplateProtocolInput {
    pub template_id: String,
    pub name: Option<String>,
    pub pool_length_m: Option<i32>,
    #[serde(default)]
    pub folder_tag: Option<String>,
    pub rounds: i32,
    pub round_rest_ms: i64,
    pub equipment: Vec<String>,
    pub target_pace_ms_per_100m: Option<i64>,
    pub notes: Option<String>,
    pub blocks: Vec<TemplateBlockInput>,
}

/// Immutable snapshot of a template's protocol at a specific version.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateVersion {
    pub id: String,
    pub template_id: String,
    pub version_number: i32,
    pub protocol_hash: String,
    pub rounds: i32,
    pub round_rest_ms: i64,
    pub equipment: Vec<String>,
    pub target_pace_ms_per_100m: Option<i64>,
    pub notes: Option<String>,
    pub total_reps: i32,
    pub total_distance_m: Option<i32>,
    pub is_homogeneous: bool,
    pub blocks: Vec<TemplateBlock>,
    pub created_at_ms: i64,
}

/// Top-level Template bundled with its active `TemplateVersion`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateWithVersion {
    pub id: String,
    pub name: String,
    pub sport_category: SportCategory,
    pub pool_length_m: Option<i32>,
    pub environment: EnvironmentType,
    #[serde(default)]
    pub folder_tag: Option<String>,
    pub is_archived: bool,
    pub active_version: TemplateVersion,
    pub total_sessions_count: i32,
    pub created_at_ms: i64,
    pub updated_at_ms: i64,
}

/// Input for a single repetition when logging a session.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RepInput {
    pub slot_index: i32,
    pub duration_ms: Option<i64>,
    pub stroke_count: Option<i32>,
    pub rpe: Option<i32>,
    pub weight_kg: Option<f64>,
    pub reps_completed: Option<i32>,
    pub attempt_result_m: Option<f64>,
    #[serde(default)]
    pub splits_ms: Vec<i64>,
    pub is_skipped: bool,
    pub notes: Option<String>,
}

/// Input payload for logging a completed session of a template.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LogSessionInput {
    pub template_id: String,
    pub template_version_id: Option<String>,
    pub workout_id: Option<String>,
    pub performed_at_ms: i64,
    pub pool_length_m: Option<i32>,
    pub notes: Option<String>,
    pub reps: Vec<RepInput>,
}

/// Stored repetition record inside a session.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RepRecord {
    pub id: String,
    pub session_id: String,
    pub slot_index: i32,
    pub round_index: i32,
    pub block_order: i32,
    pub distance_m: Option<i32>,
    pub duration_ms: Option<i64>,
    pub pace_ms_per_100m: Option<i64>,
    pub actual_rest_ms: Option<i64>,
    pub stroke_count: Option<i32>,
    /// Deterministic SWOLF efficiency score = `round(duration_sec) + stroke_count`.
    pub swolf_score: Option<i32>,
    pub rpe: Option<i32>,
    pub weight_kg: Option<f64>,
    pub reps_completed: Option<i32>,
    pub attempt_result_m: Option<f64>,
    #[serde(default)]
    pub splits_ms: Vec<i64>,
    pub is_skipped: bool,
    pub notes: Option<String>,
}

/// Deterministically computed summary metrics for a session (Multi-sport aware).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SessionSummaryMetrics {
    pub total_active_duration_ms: i64,
    pub avg_duration_ms: Option<i64>,
    pub best_rep_duration_ms: Option<i64>,
    pub worst_rep_duration_ms: Option<i64>,
    pub avg_pace_ms_per_100m: Option<i64>,
    pub std_dev_ms: Option<f64>,
    pub consistency_cv_pct: Option<f64>,
    pub fatigue_index_pct: Option<f64>,
    /// Multi-sport v1.1: Gym total tonnage (`sum(weight_kg * reps_completed)`).
    #[serde(default)]
    pub total_tonnage_kg: Option<f64>,
    /// Multi-sport v1.1: Gym best estimated 1-Rep Max via Epley formula `weight * (1 + reps/30)`.
    #[serde(default)]
    pub best_estimated_1rm_kg: Option<f64>,
    /// Multi-sport v1.1: Field best jump/throw distance or height in meters.
    #[serde(default)]
    pub best_attempt_m: Option<f64>,
}

/// Stored session bundled with its repetition records and protocol version metadata.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionWithReps {
    pub id: String,
    pub template_id: String,
    pub template_name: String,
    pub template_version_id: String,
    pub template_version_number: i32,
    pub protocol_hash: String,
    pub is_homogeneous: bool,
    pub workout_id: Option<String>,
    /// External UUID when exported to Apple HealthKit (`HKWorkout`) or Health Connect (prevents duplicate exports).
    #[serde(default)]
    pub exported_external_uuid: Option<String>,
    pub performed_at_ms: i64,
    pub pool_length_m: Option<i32>,
    pub is_completed: bool,
    pub notes: Option<String>,
    pub metrics: SessionSummaryMetrics,
    pub reps: Vec<RepRecord>,
    pub created_at_ms: i64,
}

/// Slot-by-slot comparison between two sessions of the same template protocol.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SlotDelta {
    pub slot_index: i32,
    pub distance_m: Option<i32>,
    pub current_duration_ms: Option<i64>,
    pub baseline_duration_ms: Option<i64>,
    /// `current_duration_ms - baseline_duration_ms` (negative means faster!).
    pub delta_ms: Option<i64>,
    /// `((baseline - current) / baseline) * 100.0` (positive means faster!).
    pub improvement_pct: Option<f64>,
}

/// Deterministic comparison between a current session and a baseline session.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SessionComparison {
    pub current_session_id: String,
    pub baseline_session_id: String,
    pub protocol_compatible: bool,
    pub current_version_number: i32,
    pub baseline_version_number: i32,
    pub protocol_warning: Option<String>,
    pub total_duration_delta_ms: i64,
    pub total_improvement_pct: f64,
    pub pace_delta_ms_per_100m: Option<i64>,
    pub pace_improvement_pct: Option<f64>,
    pub consistency_delta_ms: Option<f64>,
    pub slot_deltas: Vec<SlotDelta>,
}

/// Observational health context paired with a session's date (correlation, never causation).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SessionHealthCorrelationNote {
    pub session_id: String,
    pub date_iso: String,
    pub avg_pace_ms_per_100m: Option<i64>,
    pub sleep_duration_minutes: Option<i32>,
    pub hrv_sdnn_ms: Option<f64>,
    pub resting_hr_bpm: Option<f64>,
    pub observational_note: String,
}

/// Full deterministic analytics report for a Template across time.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateAnalyticsReport {
    pub template_id: String,
    pub template_name: String,
    pub active_version_number: i32,
    pub total_sessions: usize,
    pub personal_best_session_id: Option<String>,
    pub personal_best_total_duration_ms: Option<i64>,
    pub personal_best_avg_duration_ms: Option<i64>,
    pub personal_best_rep_duration_ms: Option<i64>,
    pub personal_best_pace_ms_per_100m: Option<i64>,
    pub personal_best_tonnage_kg: Option<f64>,
    pub personal_best_1rm_kg: Option<f64>,
    pub personal_best_attempt_m: Option<f64>,
    pub latest_vs_previous: Option<SessionComparison>,
    pub latest_vs_personal_best: Option<SessionComparison>,
    pub health_correlations: Vec<SessionHealthCorrelationNote>,
}

/// Workout imported from Apple HealthKit / Health Connect or logged manually.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Workout {
    pub id: String,
    pub sport_category: SportCategory,
    pub source_type: WorkoutSourceType,
    pub external_source_uuid: Option<String>,
    pub external_source_name: Option<String>,
    pub started_at_ms: i64,
    pub ended_at_ms: Option<i64>,
    pub duration_ms: Option<i64>,
    pub total_distance_m: Option<f64>,
    pub pool_length_m: Option<i32>,
    pub active_energy_kcal: Option<f64>,
    pub avg_heart_rate_bpm: Option<f64>,
    pub max_heart_rate_bpm: Option<f64>,
    #[serde(default)]
    pub has_route: bool,
    #[serde(default)]
    pub route_summary: Option<String>,
    #[serde(default)]
    pub kept_as_standalone: bool,
    #[serde(default)]
    pub associated_templates_count: i32,
    /// v1.2+: Optional recorded lap/segment durations (in ms) from Apple Watch `HKWorkoutEvent`.
    #[serde(default)]
    pub lap_durations_ms: Vec<i64>,
    pub notes: Option<String>,
    pub created_at_ms: i64,
}

/// Input payload for importing a workout from Apple HealthKit or manual entry.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImportWorkoutInput {
    pub sport_category: SportCategory,
    pub source_type: WorkoutSourceType,
    pub external_source_uuid: Option<String>,
    pub external_source_name: Option<String>,
    pub started_at_ms: i64,
    pub ended_at_ms: Option<i64>,
    pub duration_ms: Option<i64>,
    pub total_distance_m: Option<f64>,
    pub pool_length_m: Option<i32>,
    pub active_energy_kcal: Option<f64>,
    pub avg_heart_rate_bpm: Option<f64>,
    pub max_heart_rate_bpm: Option<f64>,
    #[serde(default)]
    pub has_route: bool,
    #[serde(default)]
    pub route_summary: Option<String>,
    #[serde(default)]
    pub lap_durations_ms: Vec<i64>,
    pub notes: Option<String>,
}

/// Deterministic match candidate linking an imported Workout to a Template.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TemplateMatchCandidate {
    pub template_id: String,
    pub template_name: String,
    pub template_version_id: String,
    pub template_distance_m: Option<i32>,
    pub pool_length_matches: bool,
    pub fits_remaining_distance: bool,
    pub compatibility_score: i32,
    pub deterministic_reasons: Vec<String>,
}

/// Daily health metrics snapshot (Sleep, HRV, Resting HR, VO2 Max).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct DailyHealthSnapshot {
    pub date_iso: String,
    pub sleep_duration_minutes: Option<i32>,
    pub hrv_sdnn_ms: Option<f64>,
    pub resting_hr_bpm: Option<f64>,
    pub vo2_max_ml_kg_min: Option<f64>,
    pub source_summary: Option<String>,
    pub captured_at_ms: i64,
}

/// Deterministic Health Context baseline & Bevel recovery ring metrics (Screen 7 — Health Context).
/// Obeys "Unknown != 0" (`Option<f64>` is `None` when no samples exist) and presents
/// strictly observational comparisons against personal baseline.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct HealthContextSummary {
    pub snapshots_count: usize,
    pub baseline_sleep_minutes: Option<i32>,
    pub baseline_hrv_sdnn_ms: Option<f64>,
    pub baseline_resting_hr_bpm: Option<f64>,
    pub baseline_vo2_max_ml_kg_min: Option<f64>,
    pub latest_snapshot: Option<DailyHealthSnapshot>,
    pub latest_sleep_delta_minutes: Option<i32>,
    pub latest_hrv_delta_ms: Option<f64>,
    pub latest_rhr_delta_bpm: Option<f64>,
    /// Normalized 0..=100% Bevel Sleep Ring score relative to 8h (480m) reference (`None` if unknown).
    pub bevel_sleep_ring_pct: Option<f64>,
    /// Normalized 0..=100% Bevel Recovery Context Ring derived from personal HRV & RHR baseline (`None` if unknown).
    pub bevel_recovery_ring_pct: Option<f64>,
    pub snapshots: Vec<DailyHealthSnapshot>,
}

/// Unified Daily Training Timeline for a specific `YYYY-MM-DD`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DailyTrainingTimeline {
    pub date_iso: String,
    pub workouts: Vec<Workout>,
    pub standalone_and_linked_sessions: Vec<SessionWithReps>,
    pub total_volume_distance_m: f64,
    pub total_duration_ms: i64,
    pub health_snapshot: Option<DailyHealthSnapshot>,
}

/// Result of parsing digits from the Athletic Centisecond Numpad.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct NumpadParseResult {
    pub raw_digits: String,
    pub duration_ms: i64,
    pub formatted_display: String,
}

/// Live Poolside Companion (v1.1) deterministic tick evaluation input.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LiveTimerTickInput {
    pub rest_mode: RestMode,
    pub rest_or_sendoff_ms: i64,
    /// Active swimming duration on the current repetition (if currently swimming), or final rep duration (if resting).
    pub rep_elapsed_ms: i64,
    /// Elapsed rest duration since the athlete touched the wall (`None` if still swimming the rep).
    pub rest_elapsed_ms: Option<i64>,
}

/// Live Poolside Companion (v1.1) deterministic state evaluation output.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiveTimerTickOutput {
    /// `"swimming"` | `"resting"` | `"sendoff_overrun"` | `"ready_to_depart"`
    pub phase: String,
    pub formatted_rep_time: String,
    pub remaining_rest_ms: i64,
    pub formatted_remaining_rest: String,
    /// `"none"` | `"ten_sec_warning"` | `"five_sec_warning"` | `"countdown_3_2_1"` | `"depart_now"`
    pub audio_cue: String,
    pub should_auto_advance: bool,
}

/// Full portable JSON backup container for Local-First export/restore.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatabaseBackupPayload {
    pub schema_version: i32,
    pub exported_at_ms: i64,
    pub templates: Vec<TemplateWithVersion>,
    #[serde(default)]
    pub all_template_versions: Vec<TemplateVersion>,
    pub workouts: Vec<Workout>,
    pub sessions: Vec<SessionWithReps>,
    pub health_snapshots: Vec<DailyHealthSnapshot>,
}

/// Summary returned after restoring a JSON backup (`import_json`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RestoreBackupResult {
    pub templates_restored: usize,
    pub workouts_restored: usize,
    pub sessions_restored: usize,
    pub health_snapshots_restored: usize,
}

/// Local SQLite database diagnostics summary.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DatabaseDiagnostics {
    pub engine_version: String,
    pub schema_version: i32,
    pub templates_count: i32,
    pub template_versions_count: i32,
    pub sessions_count: i32,
    pub rep_records_count: i32,
    pub workouts_count: i32,
    pub health_snapshots_count: i32,
}
