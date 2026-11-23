//! # L4NE Core (`l4ne-core` v1.1.0)
//!
//! Local-first, 100% deterministic athletic training protocol, versioning,
//! live poolside interval/send-off companion, and multi-sport performance analytics engine
//! for **L4NE Training** (iOS & Android).
//!
//! Copyright (C) 2026 John Akrivos (L4NE Performance).
//! Licensed under the GNU General Public License v3.0 (`GPL-3.0-only`).

pub mod analytics;
pub mod db;
pub mod engine;
pub mod ffi;
pub mod jni_android;
pub mod matcher;
pub mod models;

#[cfg(test)]
mod tests {
    use crate::analytics::{compare_sessions, compute_epley_1rm_kg, compute_swolf_score};
    use crate::db::L4neDatabase;
    use crate::engine::{
        compute_protocol_hash, evaluate_live_timer_tick, expand_template_slots, format_duration_ms,
        is_homogeneous_protocol, parse_athletic_numpad,
    };
    use crate::ffi::execute_command_json_str;
    use crate::models::{
        CoreError, CreateTemplateInput, EnvironmentType, ImportWorkoutInput, LiveTimerTickInput,
        LogSessionInput, RecordKind, RepInput, RestMode, SportCategory, TemplateBlockInput,
        UpdateTemplateProtocolInput, WorkoutSourceType,
    };

    #[test]
    fn test_athletic_centisecond_numpad_parser_and_formatter() {
        let p1 = parse_athletic_numpad("3240").expect("should parse 3240");
        assert_eq!(p1.duration_ms, 32_400);
        assert_eq!(p1.formatted_display, "32.40");

        let p2 = parse_athletic_numpad("10855").expect("should parse 10855");
        assert_eq!(p2.duration_ms, 68_550);
        assert_eq!(p2.formatted_display, "1:08.55");

        let p3 = parse_athletic_numpad("1795").expect("should parse 1795");
        assert_eq!(p3.duration_ms, 17_950);
        assert_eq!(p3.formatted_display, "17.95");

        assert!(parse_athletic_numpad("16500").is_err());
        assert!(parse_athletic_numpad("0000").is_err());
        assert!(parse_athletic_numpad("abc").is_err());
        assert_eq!(format_duration_ms(-2_100), "-2.10");
    }

    #[test]
    fn test_live_poolside_companion_timer_state_machine_v1_1() {
        // 1. Swimming phase on a 50s Send-Off cycle at 18.20s elapsed
        let tick_swim = evaluate_live_timer_tick(&LiveTimerTickInput {
            rest_mode: RestMode::SendOff,
            rest_or_sendoff_ms: 50_000,
            rep_elapsed_ms: 18_200,
            rest_elapsed_ms: None,
        });
        assert_eq!(tick_swim.phase, "swimming");
        assert_eq!(tick_swim.formatted_rep_time, "18.20");
        assert_eq!(tick_swim.remaining_rest_ms, 31_800);
        assert!(!tick_swim.should_auto_advance);

        // 2. Resting on wall: finished rep in 18.20s on 50s send-off -> earned 31.80s rest.
        // After 29.00s on the wall, 2.80s remain -> must trigger "countdown_3_2_1"!
        let tick_countdown = evaluate_live_timer_tick(&LiveTimerTickInput {
            rest_mode: RestMode::SendOff,
            rest_or_sendoff_ms: 50_000,
            rep_elapsed_ms: 18_200,
            rest_elapsed_ms: Some(29_000),
        });
        assert_eq!(tick_countdown.phase, "resting");
        assert_eq!(tick_countdown.remaining_rest_ms, 2_800);
        assert_eq!(tick_countdown.audio_cue, "countdown_3_2_1");

        // 3. Departure reached (rest_elapsed >= 31.80s) -> "ready_to_depart" + should_auto_advance
        let tick_go = evaluate_live_timer_tick(&LiveTimerTickInput {
            rest_mode: RestMode::SendOff,
            rest_or_sendoff_ms: 50_000,
            rep_elapsed_ms: 18_200,
            rest_elapsed_ms: Some(31_800),
        });
        assert_eq!(tick_go.phase, "ready_to_depart");
        assert_eq!(tick_go.remaining_rest_ms, 0);
        assert_eq!(tick_go.audio_cue, "depart_now");
        assert!(tick_go.should_auto_advance);
    }

    #[test]
    fn test_expand_homogeneous_pyramid_and_compound_sets() {
        let hom_blocks = vec![TemplateBlockInput {
            repeat_count: 8,
            record_kind: RecordKind::TimedDistance,
            distance_m: Some(50),
            stroke_or_movement: "surface".to_string(),
            rest_mode: RestMode::FixedRest,
            rest_or_sendoff_ms: 30_000,
            target_duration_ms: Some(18_500),
        }];
        let hom_slots = expand_template_slots(1, &hom_blocks).unwrap();
        assert_eq!(hom_slots.len(), 8);
        assert!(is_homogeneous_protocol(&hom_slots));

        let pyr_blocks: Vec<TemplateBlockInput> = [50, 100, 150, 100, 50]
            .into_iter()
            .map(|d| TemplateBlockInput {
                repeat_count: 1,
                record_kind: RecordKind::TimedDistance,
                distance_m: Some(d),
                stroke_or_movement: "bifins".to_string(),
                rest_mode: RestMode::FixedRest,
                rest_or_sendoff_ms: 30_000,
                target_duration_ms: None,
            })
            .collect();
        let pyr_slots = expand_template_slots(1, &pyr_blocks).unwrap();
        assert_eq!(pyr_slots.len(), 5);
        assert!(!is_homogeneous_protocol(&pyr_slots));
        assert_eq!(pyr_slots[2].slot_index, 3);
        assert_eq!(pyr_slots[2].distance_m, Some(150));

        let comp_blocks = vec![
            TemplateBlockInput {
                repeat_count: 2,
                record_kind: RecordKind::TimedDistance,
                distance_m: Some(50),
                stroke_or_movement: "freestyle".to_string(),
                rest_mode: RestMode::SendOff,
                rest_or_sendoff_ms: 50_000,
                target_duration_ms: None,
            },
            TemplateBlockInput {
                repeat_count: 1,
                record_kind: RecordKind::TimedDistance,
                distance_m: Some(100),
                stroke_or_movement: "freestyle".to_string(),
                rest_mode: RestMode::SendOff,
                rest_or_sendoff_ms: 100_000,
                target_duration_ms: None,
            },
        ];
        let comp_slots = expand_template_slots(4, &comp_blocks).unwrap();
        assert_eq!(comp_slots.len(), 12);
        assert!(!is_homogeneous_protocol(&comp_slots));
    }

    #[test]
    fn test_protocol_hash_distinguishes_rest_interval_and_equipment() {
        let b_60s = vec![TemplateBlockInput {
            repeat_count: 6,
            record_kind: RecordKind::TimedDistance,
            distance_m: Some(100),
            stroke_or_movement: "freestyle".to_string(),
            rest_mode: RestMode::FixedRest,
            rest_or_sendoff_ms: 60_000,
            target_duration_ms: None,
        }];
        let b_30s = vec![TemplateBlockInput {
            repeat_count: 6,
            record_kind: RecordKind::TimedDistance,
            distance_m: Some(100),
            stroke_or_movement: "freestyle".to_string(),
            rest_mode: RestMode::FixedRest,
            rest_or_sendoff_ms: 30_000,
            target_duration_ms: None,
        }];

        let h1 = compute_protocol_hash(
            SportCategory::Swimming,
            Some(50),
            EnvironmentType::Pool,
            1,
            0,
            &[],
            &b_60s,
        );
        let h2 = compute_protocol_hash(
            SportCategory::Swimming,
            Some(50),
            EnvironmentType::Pool,
            1,
            0,
            &[],
            &b_30s,
        );
        assert_ne!(h1, h2);
    }

    #[test]
    fn test_template_versioning_preserves_historical_integrity() {
        let mut db = L4neDatabase::open(":memory:").unwrap();

        let tpl = db
            .create_template(
                &CreateTemplateInput {
                    name: "6×100m Surface".to_string(),
                    sport_category: SportCategory::Finswimming,
                    pool_length_m: Some(50),
                    environment: EnvironmentType::Pool,
                    folder_tag: Some("Aerobic Threshold".to_string()),
                    rounds: 1,
                    round_rest_ms: 0,
                    equipment: vec!["monofin".to_string()],
                    target_pace_ms_per_100m: Some(40_000),
                    notes: None,
                    blocks: vec![TemplateBlockInput {
                        repeat_count: 6,
                        record_kind: RecordKind::TimedDistance,
                        distance_m: Some(100),
                        stroke_or_movement: "surface".to_string(),
                        rest_mode: RestMode::FixedRest,
                        rest_or_sendoff_ms: 60_000,
                        target_duration_ms: None,
                    }],
                },
                1_000_000,
            )
            .unwrap();
        assert_eq!(tpl.active_version.version_number, 1);
        let v1_id = tpl.active_version.id.clone();

        let s1 = db
            .log_session(
                &LogSessionInput {
                    template_id: tpl.id.clone(),
                    template_version_id: None,
                    workout_id: None,
                    performed_at_ms: 1_050_000,
                    pool_length_m: Some(50),
                    notes: None,
                    reps: (1..=6)
                        .map(|idx| RepInput {
                            slot_index: idx,
                            duration_ms: Some(41_000),
                            stroke_count: None,
                            rpe: None,
                            weight_kg: None,
                            reps_completed: None,
                            attempt_result_m: None,
                            splits_ms: vec![],
                            is_skipped: false,
                            notes: None,
                        })
                        .collect(),
                },
                1_050_000,
            )
            .unwrap();
        assert_eq!(s1.template_version_number, 1);

        let updated = db
            .update_template_protocol(
                &UpdateTemplateProtocolInput {
                    template_id: tpl.id.clone(),
                    name: Some("6×100m Surface (45s Rest)".to_string()),
                    pool_length_m: Some(50),
                    folder_tag: Some("Speed Endurance".to_string()),
                    rounds: 1,
                    round_rest_ms: 0,
                    equipment: vec!["monofin".to_string()],
                    target_pace_ms_per_100m: Some(40_000),
                    notes: None,
                    blocks: vec![TemplateBlockInput {
                        repeat_count: 6,
                        record_kind: RecordKind::TimedDistance,
                        distance_m: Some(100),
                        stroke_or_movement: "surface".to_string(),
                        rest_mode: RestMode::FixedRest,
                        rest_or_sendoff_ms: 45_000,
                        target_duration_ms: None,
                    }],
                },
                2_000_000,
            )
            .unwrap();
        assert_eq!(updated.active_version.version_number, 2);
        assert_ne!(updated.active_version.id, v1_id);

        let versions = db.list_template_versions(&tpl.id).unwrap();
        assert_eq!(versions.len(), 2);

        let reloaded_s1 = db.get_session(&s1.id).unwrap();
        assert_eq!(reloaded_s1.template_version_id, v1_id);
        assert_eq!(reloaded_s1.template_version_number, 1);

        let s2 = db
            .log_session(
                &LogSessionInput {
                    template_id: tpl.id.clone(),
                    template_version_id: None,
                    workout_id: None,
                    performed_at_ms: 2_050_000,
                    pool_length_m: Some(50),
                    notes: None,
                    reps: (1..=6)
                        .map(|idx| RepInput {
                            slot_index: idx,
                            duration_ms: Some(40_200),
                            stroke_count: None,
                            rpe: None,
                            weight_kg: None,
                            reps_completed: None,
                            attempt_result_m: None,
                            splits_ms: vec![],
                            is_skipped: false,
                            notes: None,
                        })
                        .collect(),
                },
                2_050_000,
            )
            .unwrap();
        assert_eq!(s2.template_version_number, 2);

        let cmp = compare_sessions(&s2, &reloaded_s1);
        assert!(!cmp.protocol_compatible);
        assert!(cmp.protocol_warning.is_some());
    }

    #[test]
    fn test_multisport_gym_tonnage_1rm_field_attempts_and_swolf() {
        assert_eq!(compute_swolf_score(Some(32_400), Some(15)), Some(47));
        assert_eq!(compute_epley_1rm_kg(100.0, 5), Some(116.67));

        let mut db = L4neDatabase::open(":memory:").unwrap();
        let gym_tpl = db
            .create_template(
                &CreateTemplateInput {
                    name: "5×5 Back Squat".to_string(),
                    sport_category: SportCategory::Gym,
                    pool_length_m: None,
                    environment: EnvironmentType::Gym,
                    folder_tag: Some("Strength Block".to_string()),
                    rounds: 1,
                    round_rest_ms: 0,
                    equipment: vec!["barbell".to_string()],
                    target_pace_ms_per_100m: None,
                    notes: None,
                    blocks: vec![TemplateBlockInput {
                        repeat_count: 5,
                        record_kind: RecordKind::WeightReps,
                        distance_m: None,
                        stroke_or_movement: "back_squat".to_string(),
                        rest_mode: RestMode::FixedRest,
                        rest_or_sendoff_ms: 180_000,
                        target_duration_ms: None,
                    }],
                },
                1_000_000,
            )
            .unwrap();

        let gym_s1 = db
            .log_session(
                &LogSessionInput {
                    template_id: gym_tpl.id.clone(),
                    template_version_id: None,
                    workout_id: None,
                    performed_at_ms: 1_100_000,
                    pool_length_m: None,
                    notes: None,
                    reps: (1..=5)
                        .map(|i| RepInput {
                            slot_index: i,
                            duration_ms: None,
                            stroke_count: None,
                            rpe: Some(8),
                            weight_kg: Some(120.0),
                            reps_completed: Some(5),
                            attempt_result_m: None,
                            splits_ms: vec![],
                            is_skipped: false,
                            notes: None,
                        })
                        .collect(),
                },
                1_100_000,
            )
            .unwrap();

        // 5 sets * (120kg * 5 reps) = 3,000 kg total tonnage, Epley 1RM = 120 * (1 + 5/30) = 140.0 kg
        assert_eq!(gym_s1.metrics.total_tonnage_kg, Some(3000.0));
        assert_eq!(gym_s1.metrics.best_estimated_1rm_kg, Some(140.0));
    }

    #[test]
    fn test_backup_export_restore_and_healthkit_export_dedup_v1_1() {
        let mut db1 = L4neDatabase::open(":memory:").unwrap();
        assert!(db1.seed_demo_data_if_empty().unwrap());

        // Test HealthKit session export deduplication
        let sessions = db1.list_all_sessions().unwrap();
        let first_session_id = sessions[0].id.clone();
        let exported = db1
            .mark_session_exported(&first_session_id, "HK-EXPORT-UUID-001")
            .unwrap();
        assert_eq!(
            exported.exported_external_uuid.as_deref(),
            Some("HK-EXPORT-UUID-001")
        );
        // Second export of the same session MUST be rejected!
        let dup_export = db1
            .mark_session_exported(&first_session_id, "HK-EXPORT-UUID-002")
            .unwrap_err();
        assert!(matches!(dup_export, CoreError::DuplicateExternalWorkout(_)));

        // Export full JSON backup from db1 and restore into fresh db2
        let backup_json = db1.export_backup_json(1_795_500_000_000).unwrap();

        let mut db2 = L4neDatabase::open(":memory:").unwrap();
        let restore_res = db2.import_backup_json(&backup_json).unwrap();
        assert_eq!(restore_res.templates_restored, 3);
        assert_eq!(restore_res.workouts_restored, 1);
        assert_eq!(restore_res.sessions_restored, 4);
        assert_eq!(restore_res.health_snapshots_restored, 2);

        // Second restore of same backup must be idempotent (0 duplicate templates/sessions/workouts)
        let restore_res_2 = db2.import_backup_json(&backup_json).unwrap();
        assert_eq!(restore_res_2.templates_restored, 0);
        assert_eq!(restore_res_2.workouts_restored, 0);
        assert_eq!(restore_res_2.sessions_restored, 0);

        // Verify duplicate import workout guard
        let dup_err = db1
            .import_workout(
                &ImportWorkoutInput {
                    sport_category: SportCategory::Swimming,
                    source_type: WorkoutSourceType::AppleHealth,
                    external_source_uuid: Some("HK-ULTRA2-2026-11-22-POOL50".to_string()),
                    external_source_name: Some("Apple Watch Ultra 2".to_string()),
                    started_at_ms: 1_795_356_000_000,
                    ended_at_ms: None,
                    duration_ms: Some(2_538_000),
                    total_distance_m: Some(2400.0),
                    pool_length_m: Some(50),
                    active_energy_kcal: None,
                    avg_heart_rate_bpm: None,
                    max_heart_rate_bpm: None,
                    lap_durations_ms: vec![],
                    notes: None,
                },
                1_795_356_000_000,
            )
            .unwrap_err();
        assert!(matches!(dup_err, CoreError::DuplicateExternalWorkout(_)));

        // v1.2: Verify Apple Watch lap segments auto-prefill for both Homogeneous (8x50m) and Pyramid (50-100-150-100-50m)!
        let workouts = db1.list_workouts().unwrap();
        let templates = db1.list_templates().unwrap();
        let pyramid_tpl = templates
            .iter()
            .find(|t| t.name.contains("Pyramid"))
            .unwrap();
        // Pyramid requires 1 + 2 + 3 + 2 + 1 = 9 laps of 50m; with 8 laps in the seeded workout, it prefills the first 4 slots (50, 100, 150, 100)!
        let prefilled_pyr = db1
            .prefill_reps_from_workout_laps(&workouts[0].id, &pyramid_tpl.active_version.id)
            .unwrap();
        assert_eq!(prefilled_pyr.len(), 4);
        assert_eq!(prefilled_pyr[0].duration_ms, Some(18_200)); // 50m (1 lap)
        assert_eq!(prefilled_pyr[1].duration_ms, Some(18_350 + 18_400)); // 100m (2 laps summed)
        assert_eq!(prefilled_pyr[1].splits_ms, vec![18_350, 18_400]); // intermediate 50m splits preserved!
        assert_eq!(
            prefilled_pyr[2].duration_ms,
            Some(18_300 + 18_250 + 18_300)
        ); // 150m (3 laps summed)

        // v1.2: Verify fail-closed backup restore rejects unsupported schema_version
        let bad_schema = r#"{"schema_version":99,"exported_at_ms":0,"templates":[],"workouts":[],"sessions":[],"health_snapshots":[]}"#;
        assert!(db2.import_backup_json(bad_schema).is_err());

        let ffi_numpad =
            execute_command_json_str(":memory:", r#"{"action":"parse_numpad","digits":"3240"}"#);
        assert!(ffi_numpad.contains(r#""ok":true"#));
        assert!(ffi_numpad.contains(r#""duration_ms":32400"#));
    }
}
