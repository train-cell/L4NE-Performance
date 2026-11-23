//! # L4NE Core (`l4ne-core`)
//!
//! Local-first, 100% deterministic athletic training protocol, versioning,
//! and performance analytics engine for **L4NE Training** (iOS & Android).
//!
//! Copyright (C) 2026 John Akrivos (L4NE Performance).
//! Licensed under the GNU General Public License v3.0 (`GPL-3.0-only`).

pub mod analytics;
pub mod db;
pub mod engine;
pub mod ffi;
pub mod matcher;
pub mod models;

#[cfg(test)]
mod tests {
    use crate::analytics::compare_sessions;
    use crate::db::L4neDatabase;
    use crate::engine::{
        compute_protocol_hash, expand_template_slots, format_duration_ms, is_homogeneous_protocol,
        parse_athletic_numpad,
    };
    use crate::ffi::execute_command_json_str;
    use crate::models::{
        CoreError, CreateTemplateInput, EnvironmentType, ImportWorkoutInput,
        LogSessionInput, RecordKind, RepInput, RestMode, SportCategory, TemplateBlockInput,
        UpdateTemplateProtocolInput, WorkoutSourceType,
    };

    #[test]
    fn test_athletic_centisecond_numpad_parser_and_formatter() {
        // 3240 -> 32.40s = 32,400 ms
        let p1 = parse_athletic_numpad("3240").expect("should parse 3240");
        assert_eq!(p1.duration_ms, 32_400);
        assert_eq!(p1.formatted_display, "32.40");

        // 10855 -> 1:08.55 = 68,550 ms
        let p2 = parse_athletic_numpad("10855").expect("should parse 10855");
        assert_eq!(p2.duration_ms, 68_550);
        assert_eq!(p2.formatted_display, "1:08.55");

        // 1795 -> 17.95s = 17,950 ms
        let p3 = parse_athletic_numpad("1795").expect("should parse 1795");
        assert_eq!(p3.duration_ms, 17_950);
        assert_eq!(p3.formatted_display, "17.95");

        // Reject invalid seconds >= 60 when minutes are present (e.g. 16500 -> 1m 65.00s)
        assert!(parse_athletic_numpad("16500").is_err());
        assert!(parse_athletic_numpad("0000").is_err());
        assert!(parse_athletic_numpad("abc").is_err());
        assert_eq!(format_duration_ms(-2_100), "-2.10");
    }

    #[test]
    fn test_expand_homogeneous_pyramid_and_compound_sets() {
        // 1. Homogeneous 8x50m
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

        // 2. Pyramid 50-100-150-100-50m
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

        // 3. Compound Rounds: 4 x [2x50m + 1x100m] = 12 slots
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
        assert_eq!(comp_slots[0].round_index, 1);
        assert_eq!(comp_slots[0].distance_m, Some(50));
        assert_eq!(comp_slots[2].round_index, 1);
        assert_eq!(comp_slots[2].distance_m, Some(100));
        assert_eq!(comp_slots[11].round_index, 4);
        assert_eq!(comp_slots[11].distance_m, Some(100));
    }

    #[test]
    fn test_protocol_hash_distinguishes_rest_interval_and_equipment() {
        // Overview Section 3: 6x100m @ 60s rest vs 6x100m @ 30s rest MUST be distinct protocols
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

        // Log a session against v1
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
                            is_skipped: false,
                            notes: None,
                        })
                        .collect(),
                },
                1_050_000,
            )
            .unwrap();
        assert_eq!(s1.template_version_number, 1);

        // Now modify the template's rest from 60s to 45s -> must mint v2!
        let updated = db
            .update_template_protocol(
                &UpdateTemplateProtocolInput {
                    template_id: tpl.id.clone(),
                    name: Some("6×100m Surface (45s Rest)".to_string()),
                    pool_length_m: Some(50),
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

        // Verify historical Session 1 is STILL bound to v1 with its original protocol hash!
        let reloaded_s1 = db.get_session(&s1.id).unwrap();
        assert_eq!(reloaded_s1.template_version_id, v1_id);
        assert_eq!(reloaded_s1.template_version_number, 1);

        // Log Session 2 under v2 and compare with Session 1 -> must flag protocol mismatch warning!
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
    fn test_deterministic_analytics_improvement_sendoff_and_pyramid_deltas() {
        let mut db = L4neDatabase::open(":memory:").unwrap();

        // Check exact formula from Overview Section 5:
        // Old average time 34.2s (34,200ms) -> New average time 32.1s (32,100ms) => +6.14% improvement
        let tpl = db
            .create_template(
                &CreateTemplateInput {
                    name: "4×50m Send-Off @ 1:00".to_string(),
                    sport_category: SportCategory::Swimming,
                    pool_length_m: Some(50),
                    environment: EnvironmentType::Pool,
                    rounds: 1,
                    round_rest_ms: 0,
                    equipment: vec![],
                    target_pace_ms_per_100m: None,
                    notes: None,
                    blocks: vec![TemplateBlockInput {
                        repeat_count: 4,
                        record_kind: RecordKind::TimedDistance,
                        distance_m: Some(50),
                        stroke_or_movement: "freestyle".to_string(),
                        rest_mode: RestMode::SendOff,
                        rest_or_sendoff_ms: 60_000,
                        target_duration_ms: None,
                    }],
                },
                1_000_000,
            )
            .unwrap();

        let old_session = db
            .log_session(
                &LogSessionInput {
                    template_id: tpl.id.clone(),
                    template_version_id: None,
                    workout_id: None,
                    performed_at_ms: 1_000_000,
                    pool_length_m: Some(50),
                    notes: None,
                    reps: (1..=4)
                        .map(|i| RepInput {
                            slot_index: i,
                            duration_ms: Some(34_200),
                            stroke_count: None,
                            rpe: None,
                            weight_kg: None,
                            reps_completed: None,
                            attempt_result_m: None,
                            is_skipped: false,
                            notes: None,
                        })
                        .collect(),
                },
                1_000_000,
            )
            .unwrap();

        let new_session = db
            .log_session(
                &LogSessionInput {
                    template_id: tpl.id.clone(),
                    template_version_id: None,
                    workout_id: None,
                    performed_at_ms: 2_000_000,
                    pool_length_m: Some(50),
                    notes: None,
                    reps: (1..=4)
                        .map(|i| RepInput {
                            slot_index: i,
                            duration_ms: Some(32_100),
                            stroke_count: None,
                            rpe: None,
                            weight_kg: None,
                            reps_completed: None,
                            attempt_result_m: None,
                            is_skipped: false,
                            notes: None,
                        })
                        .collect(),
                },
                2_000_000,
            )
            .unwrap();

        // Check Send-Off Actual Rest: 60,000ms - 32,100ms = 27,900ms (27.90s)
        assert_eq!(new_session.reps[0].actual_rest_ms, Some(27_900));

        // Check Improvement % = ((34.2 - 32.1) / 34.2) * 100 = 6.14%
        let cmp = compare_sessions(&new_session, &old_session);
        assert!(cmp.protocol_compatible);
        assert_eq!(cmp.total_improvement_pct, 6.14);
        assert_eq!(cmp.pace_improvement_pct, Some(6.14));
    }

    #[test]
    fn test_demo_seed_workout_deduplication_matching_timeline_and_exports() {
        let mut db = L4neDatabase::open(":memory:").unwrap();
        let seeded = db.seed_demo_data_if_empty().unwrap();
        assert!(seeded);
        assert!(!db.seed_demo_data_if_empty().unwrap());

        let templates = db.list_templates().unwrap();
        assert_eq!(templates.len(), 3);

        // Attempt duplicate Apple Watch import with same external_source_uuid -> must reject!
        let dup_err = db
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
                    notes: None,
                },
                1_795_356_000_000,
            )
            .unwrap_err();
        assert!(matches!(dup_err, CoreError::DuplicateExternalWorkout(_)));

        // Verify deterministic workout matching
        let workouts = db.list_workouts().unwrap();
        assert_eq!(workouts.len(), 1);
        let candidates = db.match_templates_for_workout(&workouts[0].id).unwrap();
        assert_eq!(candidates.len(), 3);
        assert!(candidates[0].pool_length_matches);
        assert!(candidates[0].fits_remaining_distance);

        // Verify Daily Timeline for 2026-11-22 does NOT double-count linked sessions' volume
        let timeline = db.get_daily_timeline("2026-11-22").unwrap();
        assert_eq!(timeline.workouts.len(), 1);
        assert_eq!(timeline.standalone_and_linked_sessions.len(), 2);
        assert_eq!(timeline.total_volume_distance_m, 2400.0);
        assert!(timeline.health_snapshot.is_some());

        // Verify JSON backup & CSV export
        let json_backup = db.export_backup_json(1_795_356_000_000).unwrap();
        assert!(json_backup.contains("8×50m Surface Monofin"));
        let csv = db.export_sessions_csv().unwrap();
        assert!(csv.contains("session_id,date_iso,template_name"));

        // Verify FFI JSON command router
        let ffi_numpad =
            execute_command_json_str(":memory:", r#"{"action":"parse_numpad","digits":"3240"}"#);
        assert!(ffi_numpad.contains(r#""ok":true"#));
        assert!(ffi_numpad.contains(r#""duration_ms":32400"#));
    }
}
