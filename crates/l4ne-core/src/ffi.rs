//! C-ABI Foreign Function Interface (`l4ne_core::ffi`) for Swift (iOS/macOS) and Kotlin/JNI (Android).

use crate::analytics::compare_sessions;
use crate::db::L4neDatabase;
use crate::engine::{evaluate_live_timer_tick, parse_athletic_numpad};
use crate::models::{
    AppSettings, CoreError, CreateTemplateInput, DailyHealthSnapshot, ImportWorkoutInput,
    LiveTimerTickInput, LogSessionInput, UpdateTemplateProtocolInput,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::time::{SystemTime, UNIX_EPOCH};

const VERSION_CSTR: &[u8] = b"1.3.0\0";

fn current_epoch_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(1_795_356_000_000)
}

#[derive(Debug, Deserialize)]
#[serde(tag = "action", rename_all = "snake_case")]
pub enum FfiCommand {
    ListTemplates {
        #[serde(default)]
        include_archived: bool,
    },
    GetTemplate {
        template_id: String,
    },
    ListTemplateVersions {
        template_id: String,
    },
    CreateTemplate {
        payload: CreateTemplateInput,
        now_ms: Option<i64>,
    },
    UpdateTemplateProtocol {
        payload: UpdateTemplateProtocolInput,
        now_ms: Option<i64>,
    },
    SetTemplateArchived {
        template_id: String,
        is_archived: bool,
        now_ms: Option<i64>,
    },
    ExpandTemplateSlots {
        template_version_id: String,
    },
    LogSession {
        payload: LogSessionInput,
        now_ms: Option<i64>,
    },
    DeleteSession {
        session_id: String,
    },
    LinkSessionToWorkout {
        session_id: String,
        workout_id: Option<String>,
    },
    MarkSessionExported {
        session_id: String,
        external_uuid: String,
    },
    ListSessions {
        template_id: Option<String>,
    },
    TemplateAnalytics {
        template_id: String,
    },
    CompareSessions {
        current_session_id: String,
        baseline_session_id: String,
    },
    ImportWorkout {
        payload: ImportWorkoutInput,
        now_ms: Option<i64>,
    },
    SetWorkoutStandalone {
        workout_id: String,
        kept_as_standalone: bool,
    },
    ListWorkouts,
    MatchWorkoutTemplates {
        workout_id: String,
    },
    PrefillRepsFromWorkoutLaps {
        workout_id: String,
        template_version_id: String,
    },
    UpsertHealthSnapshot {
        payload: DailyHealthSnapshot,
    },
    ListHealthSnapshots,
    HealthContextSummary,
    GetAppSettings,
    UpdateAppSettings {
        payload: AppSettings,
    },
    DailyTimeline {
        date_iso: String,
    },
    ParseNumpad {
        digits: String,
    },
    ComputeLiveTimerTick {
        payload: LiveTimerTickInput,
    },
    ExportJson {
        now_ms: Option<i64>,
    },
    ImportJson {
        backup_json: String,
    },
    ExportCsv,
    DatabaseStats,
}

#[derive(Debug, Serialize)]
pub struct FfiEnvelope {
    pub ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

impl FfiEnvelope {
    pub fn success<T: Serialize>(value: T) -> String {
        let env = Self {
            ok: true,
            data: serde_json::to_value(value).ok(),
            error: None,
        };
        serde_json::to_string(&env)
            .unwrap_or_else(|e| format!(r#"{{"ok":false,"error":"Serialization error: {e}"}}"#))
    }

    pub fn failure(msg: impl Into<String>) -> String {
        let env = Self {
            ok: false,
            data: None,
            error: Some(msg.into()),
        };
        serde_json::to_string(&env)
            .unwrap_or_else(|_| r#"{"ok":false,"error":"Internal FFI error"}"#.to_string())
    }
}

fn into_c_string(s: String) -> *mut c_char {
    CString::new(s)
        .unwrap_or_else(|_| CString::new(r#"{"ok":false,"error":"NUL byte in response"}"#).unwrap())
        .into_raw()
}

/// Pure Rust handler for executing an `FfiCommand` JSON string against `db_path`.
pub fn execute_command_json_str(db_path: &str, request_json: &str) -> String {
    let cmd: FfiCommand = match serde_json::from_str(request_json) {
        Ok(c) => c,
        Err(e) => return FfiEnvelope::failure(format!("Invalid request JSON: {e}")),
    };

    match &cmd {
        FfiCommand::ParseNumpad { digits } => {
            return match parse_athletic_numpad(digits) {
                Ok(res) => FfiEnvelope::success(res),
                Err(e) => FfiEnvelope::failure(e.to_string()),
            };
        }
        FfiCommand::ComputeLiveTimerTick { payload } => {
            return FfiEnvelope::success(evaluate_live_timer_tick(payload));
        }
        _ => {}
    }

    let mut db = match L4neDatabase::open(db_path) {
        Ok(d) => d,
        Err(e) => return FfiEnvelope::failure(e.to_string()),
    };

    let result: Result<Value, CoreError> = (|| match cmd {
        FfiCommand::ListTemplates { include_archived } => Ok(serde_json::to_value(
            db.list_templates_filtered(include_archived)?,
        )?),
        FfiCommand::GetTemplate { template_id } => {
            Ok(serde_json::to_value(db.get_template(&template_id)?)?)
        }
        FfiCommand::ListTemplateVersions { template_id } => Ok(serde_json::to_value(
            db.list_template_versions(&template_id)?,
        )?),
        FfiCommand::CreateTemplate { payload, now_ms } => Ok(serde_json::to_value(
            db.create_template(&payload, now_ms.unwrap_or_else(current_epoch_ms))?,
        )?),
        FfiCommand::UpdateTemplateProtocol { payload, now_ms } => Ok(serde_json::to_value(
            db.update_template_protocol(&payload, now_ms.unwrap_or_else(current_epoch_ms))?,
        )?),
        FfiCommand::SetTemplateArchived {
            template_id,
            is_archived,
            now_ms,
        } => Ok(serde_json::to_value(db.set_template_archived(
            &template_id,
            is_archived,
            now_ms.unwrap_or_else(current_epoch_ms),
        )?)?),
        FfiCommand::ExpandTemplateSlots {
            template_version_id,
        } => Ok(serde_json::to_value(
            db.expand_version_slots(&template_version_id)?,
        )?),
        FfiCommand::LogSession { payload, now_ms } => Ok(serde_json::to_value(
            db.log_session(&payload, now_ms.unwrap_or_else(current_epoch_ms))?,
        )?),
        FfiCommand::DeleteSession { session_id } => {
            let deleted = db.delete_session(&session_id)?;
            Ok(json!({ "deleted": deleted }))
        }
        FfiCommand::LinkSessionToWorkout {
            session_id,
            workout_id,
        } => Ok(serde_json::to_value(
            db.link_session_to_workout(&session_id, workout_id.as_deref())?,
        )?),
        FfiCommand::MarkSessionExported {
            session_id,
            external_uuid,
        } => Ok(serde_json::to_value(
            db.mark_session_exported(&session_id, &external_uuid)?,
        )?),
        FfiCommand::ListSessions { template_id } => match template_id {
            Some(tid) => Ok(serde_json::to_value(db.list_sessions_for_template(&tid)?)?),
            None => Ok(serde_json::to_value(db.list_all_sessions()?)?),
        },
        FfiCommand::TemplateAnalytics { template_id } => Ok(serde_json::to_value(
            db.get_template_analytics(&template_id)?,
        )?),
        FfiCommand::CompareSessions {
            current_session_id,
            baseline_session_id,
        } => {
            let cur = db.get_session(&current_session_id)?;
            let base = db.get_session(&baseline_session_id)?;
            Ok(serde_json::to_value(compare_sessions(&cur, &base))?)
        }
        FfiCommand::ImportWorkout { payload, now_ms } => Ok(serde_json::to_value(
            db.import_workout(&payload, now_ms.unwrap_or_else(current_epoch_ms))?,
        )?),
        FfiCommand::SetWorkoutStandalone {
            workout_id,
            kept_as_standalone,
        } => Ok(serde_json::to_value(
            db.set_workout_standalone(&workout_id, kept_as_standalone)?,
        )?),
        FfiCommand::ListWorkouts => Ok(serde_json::to_value(db.list_workouts()?)?),
        FfiCommand::MatchWorkoutTemplates { workout_id } => Ok(serde_json::to_value(
            db.match_templates_for_workout(&workout_id)?,
        )?),
        FfiCommand::PrefillRepsFromWorkoutLaps {
            workout_id,
            template_version_id,
        } => Ok(serde_json::to_value(
            db.prefill_reps_from_workout_laps(&workout_id, &template_version_id)?,
        )?),
        FfiCommand::UpsertHealthSnapshot { payload } => {
            Ok(serde_json::to_value(db.upsert_health_snapshot(&payload)?)?)
        }
        FfiCommand::ListHealthSnapshots => Ok(serde_json::to_value(db.list_health_snapshots()?)?),
        FfiCommand::HealthContextSummary => {
            Ok(serde_json::to_value(db.get_health_context_summary()?)?)
        }
        FfiCommand::GetAppSettings => Ok(serde_json::to_value(db.get_app_settings()?)?),
        FfiCommand::UpdateAppSettings { payload } => {
            Ok(serde_json::to_value(db.update_app_settings(&payload)?)?)
        }
        FfiCommand::DailyTimeline { date_iso } => {
            Ok(serde_json::to_value(db.get_daily_timeline(&date_iso)?)?)
        }
        FfiCommand::ExportJson { now_ms } => {
            let raw = db.export_backup_json(now_ms.unwrap_or_else(current_epoch_ms))?;
            Ok(json!({ "json": raw }))
        }
        FfiCommand::ImportJson { backup_json } => {
            Ok(serde_json::to_value(db.import_backup_json(&backup_json)?)?)
        }
        FfiCommand::ExportCsv => {
            let csv = db.export_sessions_csv()?;
            Ok(json!({ "csv": csv }))
        }
        FfiCommand::DatabaseStats => Ok(serde_json::to_value(db.get_database_diagnostics()?)?),
        FfiCommand::ParseNumpad { .. } | FfiCommand::ComputeLiveTimerTick { .. } => unreachable!(),
    })();

    match result {
        Ok(val) => FfiEnvelope::success(val),
        Err(e) => FfiEnvelope::failure(e.to_string()),
    }
}

/// Returns the semantic version of `l4ne-core` ("1.1.0").
#[no_mangle]
pub extern "C" fn l4ne_core_version() -> *const c_char {
    VERSION_CSTR.as_ptr() as *const c_char
}

/// Initializes/migrates the database at `db_path` and optionally seeds demo templates and sessions.
#[no_mangle]
pub unsafe extern "C" fn l4ne_init_database_json(
    db_path: *const c_char,
    seed_demo: bool,
) -> *mut c_char {
    if db_path.is_null() {
        return into_c_string(FfiEnvelope::failure("db_path pointer is null"));
    }
    let path_str = match CStr::from_ptr(db_path).to_str() {
        Ok(s) => s,
        Err(e) => return into_c_string(FfiEnvelope::failure(format!("Invalid UTF-8 path: {e}"))),
    };

    let res = (|| -> Result<Value, CoreError> {
        let mut db = L4neDatabase::open(path_str)?;
        let seeded = if seed_demo {
            db.seed_demo_data_if_empty()?
        } else {
            false
        };
        let templates = db.list_templates()?;
        Ok(json!({
            "seeded": seeded,
            "templates_count": templates.len(),
            "engine_version": "1.3.0"
        }))
    })();

    match res {
        Ok(v) => into_c_string(FfiEnvelope::success(v)),
        Err(e) => into_c_string(FfiEnvelope::failure(e.to_string())),
    }
}

/// Executes a JSON command against the local SQLite database at `db_path`.
#[no_mangle]
pub unsafe extern "C" fn l4ne_execute_json(
    db_path: *const c_char,
    request_json: *const c_char,
) -> *mut c_char {
    if db_path.is_null() || request_json.is_null() {
        return into_c_string(FfiEnvelope::failure(
            "db_path or request_json pointer is null",
        ));
    }
    let path_str = match CStr::from_ptr(db_path).to_str() {
        Ok(s) => s,
        Err(e) => return into_c_string(FfiEnvelope::failure(format!("Invalid UTF-8 path: {e}"))),
    };
    let req_str = match CStr::from_ptr(request_json).to_str() {
        Ok(s) => s,
        Err(e) => {
            return into_c_string(FfiEnvelope::failure(format!(
                "Invalid UTF-8 request_json: {e}"
            )))
        }
    };

    into_c_string(execute_command_json_str(path_str, req_str))
}

/// Frees a C string allocated by `l4ne-core`.
#[no_mangle]
pub unsafe extern "C" fn l4ne_string_free(ptr: *mut c_char) {
    if !ptr.is_null() {
        let _ = CString::from_raw(ptr);
    }
}
