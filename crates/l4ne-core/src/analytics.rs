//! Deterministic Performance Analytics Engine (`l4ne_core::analytics`).
//!
//! 100% mathematical & deterministic calculations — zero AI, zero heuristics.
//! Supports:
//! - Homogeneous & Pyramid/Compound sets for Swimming, Finswimming, and Track (`timed_distance`)
//! - Field Throws & Jumps (`distance_attempt`: best attempt, average, progression)
//! - Gym Strength Training (`weight_reps`: total tonnage kg, Epley estimated 1RM kg, average RPE)

use crate::engine::format_duration_ms;
use crate::models::{
    CoreError, DailyHealthSnapshot, ExpectedRepSlot, HealthContextSummary, PcrPredictionResult,
    PcrRecalculatorInput, PcrSegmentBreakdown, PcrSegmentInput, RepRecord, RestMode,
    SessionComparison, SessionHealthCorrelationNote, SessionSummaryMetrics, SessionWithReps,
    SlotDelta, TemplateAnalyticsReport, TemplateWithVersion,
};
use std::collections::HashMap;

/// Computes normalized pace in milliseconds per 100 meters (`ms / 100m`).
pub fn compute_pace_ms_per_100m(duration_ms: i64, distance_m: i32) -> Option<i64> {
    if duration_ms <= 0 || distance_m <= 0 {
        return None;
    }
    let d = distance_m as i64;
    Some(((duration_ms * 100) + (d / 2)) / d)
}

/// Computes deterministic SWOLF score (`round(duration_sec) + stroke_count`).
pub fn compute_swolf_score(duration_ms: Option<i64>, stroke_count: Option<i32>) -> Option<i32> {
    match (duration_ms, stroke_count) {
        (Some(dur), Some(strokes)) if dur > 0 && strokes > 0 => {
            let secs = ((dur + 500) / 1000) as i32;
            Some(secs + strokes)
        }
        _ => None,
    }
}

/// Computes Epley Estimated 1-Rep Max (`weight * (1 + reps / 30.0)`).
pub fn compute_epley_1rm_kg(weight_kg: f64, reps: i32) -> Option<f64> {
    if weight_kg <= 0.0 || reps <= 0 {
        return None;
    }
    if reps == 1 {
        return Some(round2(weight_kg));
    }
    Some(round2(weight_kg * (1.0 + (reps as f64 / 30.0))))
}

/// Computes actual rest time in milliseconds for a repetition given the block's `RestMode`.
pub fn compute_actual_rest_ms(
    rest_mode: RestMode,
    rest_or_sendoff_ms: i64,
    duration_ms: Option<i64>,
) -> Option<i64> {
    match rest_mode {
        RestMode::FixedRest => Some(rest_or_sendoff_ms.max(0)),
        RestMode::SendOff => duration_ms.map(|dur| (rest_or_sendoff_ms - dur).max(0)),
    }
}

/// Rounds a floating-point metric to 2 decimal places deterministically.
fn round2(val: f64) -> f64 {
    (val * 100.0).round() / 100.0
}

/// Computes deterministic summary metrics for a session across Timed, Field, and Gym records.
pub fn compute_session_metrics(
    _slots: &[ExpectedRepSlot],
    reps: &[RepRecord],
    is_homogeneous: bool,
) -> SessionSummaryMetrics {
    let active_reps: Vec<&RepRecord> = reps.iter().filter(|r| !r.is_skipped).collect();

    // Multi-sport v1.1: Gym tonnage & Epley 1RM
    let mut tonnage_sum = 0.0f64;
    let mut has_gym = false;
    let mut best_1rm: Option<f64> = None;

    // Multi-sport v1.1: Field best attempt (meters)
    let mut best_attempt_m: Option<f64> = None;

    for r in &active_reps {
        if let (Some(w), Some(rc)) = (r.weight_kg, r.reps_completed) {
            if w > 0.0 && rc > 0 {
                has_gym = true;
                tonnage_sum += w * (rc as f64);
                if let Some(est) = compute_epley_1rm_kg(w, rc) {
                    best_1rm = Some(best_1rm.map_or(est, |cur| cur.max(est)));
                }
            }
        }
        if let Some(att) = r.attempt_result_m {
            if att > 0.0 {
                let rounded = round2(att);
                best_attempt_m = Some(best_attempt_m.map_or(rounded, |cur| cur.max(rounded)));
            }
        }
    }

    let total_tonnage_kg = if has_gym {
        Some(round2(tonnage_sum))
    } else {
        None
    };

    let valid_timed_reps: Vec<&RepRecord> = active_reps
        .iter()
        .copied()
        .filter(|r| r.duration_ms.unwrap_or(0) > 0)
        .collect();

    if valid_timed_reps.is_empty() {
        return SessionSummaryMetrics {
            total_active_duration_ms: 0,
            avg_duration_ms: None,
            best_rep_duration_ms: None,
            worst_rep_duration_ms: None,
            avg_pace_ms_per_100m: None,
            std_dev_ms: None,
            consistency_cv_pct: None,
            fatigue_index_pct: None,
            total_tonnage_kg,
            best_estimated_1rm_kg: best_1rm,
            best_attempt_m,
        };
    }

    let durations: Vec<i64> = valid_timed_reps
        .iter()
        .filter_map(|r| r.duration_ms)
        .collect();
    let total_active_duration_ms: i64 = durations.iter().sum();
    let count = durations.len() as i64;

    let (avg_duration_ms, best_rep_duration_ms, worst_rep_duration_ms) = if is_homogeneous {
        let avg = (total_active_duration_ms + (count / 2)) / count;
        let best = durations.iter().copied().min();
        let worst = durations.iter().copied().max();
        (Some(avg), best, worst)
    } else {
        (None, None, None)
    };

    let mut total_dist_m: i64 = 0;
    let mut total_timed_dist_ms: i64 = 0;
    for r in &valid_timed_reps {
        if let (Some(dur), Some(dist)) = (r.duration_ms, r.distance_m) {
            if dist > 0 {
                total_dist_m += dist as i64;
                total_timed_dist_ms += dur;
            }
        }
    }

    let avg_pace_ms_per_100m = if total_dist_m > 0 {
        Some(((total_timed_dist_ms * 100) + (total_dist_m / 2)) / total_dist_m)
    } else {
        None
    };

    let series_for_dispersion: Vec<f64> = if is_homogeneous {
        durations.iter().map(|&d| d as f64).collect()
    } else {
        valid_timed_reps
            .iter()
            .filter_map(|r| r.pace_ms_per_100m.map(|p| p as f64))
            .collect()
    };

    let (std_dev_ms, consistency_cv_pct) = if series_for_dispersion.len() >= 2 {
        let n = series_for_dispersion.len() as f64;
        let mean = series_for_dispersion.iter().sum::<f64>() / n;
        let variance = series_for_dispersion
            .iter()
            .map(|&v| {
                let diff = v - mean;
                diff * diff
            })
            .sum::<f64>()
            / n;
        let std_dev = variance.sqrt();
        let cv = if mean > 0.0 {
            Some(round2((std_dev / mean) * 100.0))
        } else {
            None
        };
        (Some(round2(std_dev)), cv)
    } else {
        (None, None)
    };

    let fatigue_index_pct = if valid_timed_reps.len() >= 2 {
        let half = valid_timed_reps.len() / 2;
        let first_half = &valid_timed_reps[..half];
        let second_half = &valid_timed_reps[valid_timed_reps.len() - half..];

        let half_metric = |slice: &[&RepRecord]| -> Option<f64> {
            let mut d_sum = 0i64;
            let mut t_sum = 0i64;
            for r in slice {
                if let (Some(dur), Some(dist)) = (r.duration_ms, r.distance_m) {
                    if dist > 0 {
                        d_sum += dist as i64;
                        t_sum += dur;
                    }
                }
            }
            if d_sum > 0 {
                Some((t_sum as f64 * 100.0) / d_sum as f64)
            } else {
                let dur_sum: i64 = slice.iter().filter_map(|r| r.duration_ms).sum();
                if !slice.is_empty() {
                    Some(dur_sum as f64 / slice.len() as f64)
                } else {
                    None
                }
            }
        };

        match (half_metric(first_half), half_metric(second_half)) {
            (Some(p1), Some(p2)) if p1 > 0.0 => Some(round2(((p2 - p1) / p1) * 100.0)),
            _ => None,
        }
    } else {
        None
    };

    SessionSummaryMetrics {
        total_active_duration_ms,
        avg_duration_ms,
        best_rep_duration_ms,
        worst_rep_duration_ms,
        avg_pace_ms_per_100m,
        std_dev_ms,
        consistency_cv_pct,
        fatigue_index_pct,
        total_tonnage_kg,
        best_estimated_1rm_kg: best_1rm,
        best_attempt_m,
    }
}

/// Deterministically compares two sessions (`current` vs `baseline`).
pub fn compare_sessions(
    current: &SessionWithReps,
    baseline: &SessionWithReps,
) -> SessionComparison {
    let protocol_compatible = current.protocol_hash == baseline.protocol_hash;
    let protocol_warning = if !protocol_compatible {
        Some(format!(
            "Protocol changed between baseline (v{}) and current (v{}). Direct equivalence is approximate.",
            baseline.template_version_number, current.template_version_number
        ))
    } else {
        None
    };

    let cur_total = current.metrics.total_active_duration_ms;
    let base_total = baseline.metrics.total_active_duration_ms;
    let total_duration_delta_ms = cur_total - base_total;

    // For timed sports, lower duration = positive improvement.
    // For Gym tonnage or Field attempts (when duration is 0), higher tonnage/attempt = positive improvement!
    let total_improvement_pct = if base_total > 0 {
        round2(((base_total - cur_total) as f64 / base_total as f64) * 100.0)
    } else if let (Some(cur_ton), Some(base_ton)) = (
        current.metrics.total_tonnage_kg,
        baseline.metrics.total_tonnage_kg,
    ) {
        if base_ton > 0.0 {
            round2(((cur_ton - base_ton) / base_ton) * 100.0)
        } else {
            0.0
        }
    } else if let (Some(cur_att), Some(base_att)) =
        (current.metrics.best_attempt_m, baseline.metrics.best_attempt_m)
    {
        if base_att > 0.0 {
            round2(((cur_att - base_att) / base_att) * 100.0)
        } else {
            0.0
        }
    } else {
        0.0
    };

    let (pace_delta_ms_per_100m, pace_improvement_pct) = match (
        current.metrics.avg_pace_ms_per_100m,
        baseline.metrics.avg_pace_ms_per_100m,
    ) {
        (Some(cur_p), Some(base_p)) if base_p > 0 => {
            let delta = cur_p - base_p;
            let imp = round2(((base_p - cur_p) as f64 / base_p as f64) * 100.0);
            (Some(delta), Some(imp))
        }
        _ => (None, None),
    };

    let consistency_delta_ms = match (current.metrics.std_dev_ms, baseline.metrics.std_dev_ms) {
        (Some(cur_sd), Some(base_sd)) => Some(round2(cur_sd - base_sd)),
        _ => None,
    };

    let base_by_slot: HashMap<i32, &RepRecord> =
        baseline.reps.iter().map(|r| (r.slot_index, r)).collect();

    let mut slot_deltas = Vec::with_capacity(current.reps.len());
    for cur_rep in &current.reps {
        let base_rep = base_by_slot.get(&cur_rep.slot_index).copied();
        let cur_dur = if cur_rep.is_skipped {
            None
        } else {
            cur_rep.duration_ms
        };
        let base_dur = base_rep.and_then(|r| if r.is_skipped { None } else { r.duration_ms });

        let (delta_ms, improvement_pct) = match (cur_dur, base_dur) {
            (Some(c), Some(b)) if b > 0 => {
                let d = c - b;
                let imp = round2(((b - c) as f64 / b as f64) * 100.0);
                (Some(d), Some(imp))
            }
            _ => (None, None),
        };

        slot_deltas.push(SlotDelta {
            slot_index: cur_rep.slot_index,
            distance_m: cur_rep.distance_m,
            current_duration_ms: cur_dur,
            baseline_duration_ms: base_dur,
            delta_ms,
            improvement_pct,
        });
    }

    SessionComparison {
        current_session_id: current.id.clone(),
        baseline_session_id: baseline.id.clone(),
        protocol_compatible,
        current_version_number: current.template_version_number,
        baseline_version_number: baseline.template_version_number,
        protocol_warning,
        total_duration_delta_ms,
        total_improvement_pct,
        pace_delta_ms_per_100m,
        pace_improvement_pct,
        consistency_delta_ms,
        slot_deltas,
    }
}

/// Converts a UNIX epoch timestamp in milliseconds (`i64`) to a UTC `YYYY-MM-DD` date string.
pub fn epoch_ms_to_date_iso(epoch_ms: i64) -> String {
    let days = epoch_ms.div_euclid(86_400_000);
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = (z - era * 146_097) as u32;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365;
    let y = (yoe as i64) + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let year = if m <= 2 { y + 1 } else { y };
    format!("{year:04}-{m:02}-{d:02}")
}

/// Builds a comprehensive `TemplateAnalyticsReport` across all historical sessions of a template.
pub fn compute_template_analytics(
    template: &TemplateWithVersion,
    sessions_chronological_desc: &[SessionWithReps],
    health_snapshots: &[DailyHealthSnapshot],
) -> TemplateAnalyticsReport {
    let compatible_sessions: Vec<&SessionWithReps> = sessions_chronological_desc
        .iter()
        .filter(|s| s.protocol_hash == template.active_version.protocol_hash)
        .collect();

    let timed_compatible: Vec<&SessionWithReps> = compatible_sessions
        .iter()
        .copied()
        .filter(|s| s.metrics.total_active_duration_ms > 0)
        .collect();

    let pb_session = if !timed_compatible.is_empty() {
        timed_compatible.iter().copied().min_by_key(|s| {
            s.metrics
                .avg_pace_ms_per_100m
                .unwrap_or(s.metrics.total_active_duration_ms)
        })
    } else {
        compatible_sessions.first().copied()
    };

    let personal_best_rep_duration_ms = if template.active_version.is_homogeneous {
        timed_compatible
            .iter()
            .filter_map(|s| s.metrics.best_rep_duration_ms)
            .min()
    } else {
        None
    };

    let personal_best_tonnage_kg = compatible_sessions
        .iter()
        .filter_map(|s| s.metrics.total_tonnage_kg)
        .reduce(f64::max);

    let personal_best_1rm_kg = compatible_sessions
        .iter()
        .filter_map(|s| s.metrics.best_estimated_1rm_kg)
        .reduce(f64::max);

    let personal_best_attempt_m = compatible_sessions
        .iter()
        .filter_map(|s| s.metrics.best_attempt_m)
        .reduce(f64::max);

    let latest_vs_previous = if sessions_chronological_desc.len() >= 2 {
        Some(compare_sessions(
            &sessions_chronological_desc[0],
            &sessions_chronological_desc[1],
        ))
    } else {
        None
    };

    let latest_vs_personal_best = match (sessions_chronological_desc.first(), pb_session) {
        (Some(latest), Some(pb)) if latest.id != pb.id => Some(compare_sessions(latest, pb)),
        _ => None,
    };

    let snapshots_by_date: HashMap<&str, &DailyHealthSnapshot> = health_snapshots
        .iter()
        .map(|h| (h.date_iso.as_str(), h))
        .collect();

    let mut health_correlations = Vec::new();
    for session in sessions_chronological_desc {
        let date_iso = epoch_ms_to_date_iso(session.performed_at_ms);
        if let Some(snap) = snapshots_by_date.get(date_iso.as_str()) {
            let mut parts = Vec::new();
            if let Some(sleep_min) = snap.sleep_duration_minutes {
                parts.push(format!("Sleep {}h {:02}m", sleep_min / 60, sleep_min % 60));
            }
            if let Some(hrv) = snap.hrv_sdnn_ms {
                parts.push(format!("HRV {:.1} ms", hrv));
            }
            if let Some(rhr) = snap.resting_hr_bpm {
                parts.push(format!("RHR {:.0} bpm", rhr));
            }
            let observational_note = if parts.is_empty() {
                "Health snapshot recorded without sleep/HRV samples.".to_string()
            } else {
                format!(
                    "Coincided with {} (observational correlation only, not causal proof).",
                    parts.join(" · ")
                )
            };

            health_correlations.push(SessionHealthCorrelationNote {
                session_id: session.id.clone(),
                date_iso,
                avg_pace_ms_per_100m: session.metrics.avg_pace_ms_per_100m,
                sleep_duration_minutes: snap.sleep_duration_minutes,
                hrv_sdnn_ms: snap.hrv_sdnn_ms,
                resting_hr_bpm: snap.resting_hr_bpm,
                observational_note,
            });
        }
    }

    let pcr_predictions =
        compute_template_pcr_predictions(template, sessions_chronological_desc);

    TemplateAnalyticsReport {
        template_id: template.id.clone(),
        template_name: template.name.clone(),
        active_version_number: template.active_version.version_number,
        total_sessions: sessions_chronological_desc.len(),
        personal_best_session_id: pb_session.map(|s| s.id.clone()),
        personal_best_total_duration_ms: pb_session.map(|s| s.metrics.total_active_duration_ms),
        personal_best_avg_duration_ms: pb_session.and_then(|s| s.metrics.avg_duration_ms),
        personal_best_rep_duration_ms,
        personal_best_pace_ms_per_100m: pb_session.and_then(|s| s.metrics.avg_pace_ms_per_100m),
        personal_best_tonnage_kg,
        personal_best_1rm_kg,
        personal_best_attempt_m,
        latest_vs_previous,
        latest_vs_personal_best,
        health_correlations,
        pcr_predictions,
    }
}

/// Default PCr time constant `τ = 28.0s` (`ΤΗΕ ΘΕΩΡΙ.txt` §2 & `broken_set.py`).
pub const PCR_TAU_DEFAULT_SEC: f64 = 28.0;
/// Oracle 200m -> 400m conversion factor (`broken_set.py`).
pub const PCR_ORACLE_200_TO_400_RATIO: f64 = 2.17;

/// Returns the default distance coefficient `k` for a target race distance (`ΤΗΕ ΘΕΩΡΙ.txt` §2):
/// - `200m` (and `<= 200m`): `k = 0.16`
/// - `400m`: `k = 0.13`
/// - `>= 800m`: `k = 0.11`
pub fn default_pcr_k_for_distance(target_distance_m: i32) -> f64 {
    if target_distance_m <= 200 {
        0.16
    } else if target_distance_m <= 400 {
        0.13
    } else {
        0.11
    }
}

/// Evaluates the Segmented PCr Race Prediction Model (`ΤΗΕ ΘΕΩΡΙ.txt` v2.0).
///
/// Rules:
/// 1. `Recovery(t) = 1 - e^(-t / τ)` where `t` is rest in seconds and `τ = 28.0s` (default).
/// 2. `Δ = (k * Recovery) + FF` where `k = 0.16` (200m) or `0.13` (400m), and `FF = 0.00` (`t < 20s`)
///    or `0.015` (`t >= 20s` after deep lactic load).
/// 3. **Segmented Penalty Rule (§1 & §4)**:
///    - If the first segment is `> 150m` continuous (e.g. `200m + 20s stop + 150m`), Segment 1 receives
///      **0% penalty** (`Δ_1 = 0`), and the penalty `Δ_i` is applied strictly to segments following a rest stop.
///      Any remaining distance `target_distance_m - swum_distance_m` (e.g. `50m` in a `350m -> 400m` set)
///      is added via `tail_override_ms` or heavy-fatigue tail pace extrapolation.
///    - If all segments are `<= 150m` (e.g. `4×50m`, `8×50m`, `4×100m`), applies the symmetric broken set
///      penalty `T_race = T_broken * (1 + Δ)`.
pub fn calculate_pcr_prediction(
    input: &PcrRecalculatorInput,
) -> Result<PcrPredictionResult, CoreError> {
    if input.target_distance_m <= 0 {
        return Err(CoreError::Validation(
            "Target distance must be > 0m".to_string(),
        ));
    }
    if input.segments.is_empty() {
        return Err(CoreError::Validation(
            "PCr Recalculator requires at least one segment".to_string(),
        ));
    }
    for (idx, s) in input.segments.iter().enumerate() {
        if s.distance_m <= 0 || s.duration_ms <= 0 {
            return Err(CoreError::Validation(format!(
                "Segment #{} distance and duration must be > 0",
                idx + 1
            )));
        }
    }

    let tau = input
        .tau_seconds
        .filter(|&v| v > 0.0 && v.is_finite())
        .unwrap_or(PCR_TAU_DEFAULT_SEC);
    let k = input
        .custom_k
        .filter(|&v| v > 0.0 && v.is_finite())
        .unwrap_or_else(|| default_pcr_k_for_distance(input.target_distance_m));

    let swum_distance_m: i32 = input.segments.iter().map(|s| s.distance_m).sum();
    let raw_broken_time_ms: i64 = input.segments.iter().map(|s| s.duration_ms).sum();
    let is_segmented_mode = input.segments[0].distance_m > 150;

    let mut breakdowns = Vec::with_capacity(input.segments.len());

    if is_segmented_mode {
        let mut total_adjusted_ms = 0i64;
        let mut rest_sum_sec = 0.0f64;
        let mut rest_count = 0usize;
        let mut last_rec = 0.0f64;
        let mut last_delta_pct = 0.0f64;
        let mut last_ff = 0.0f64;

        for (idx, seg) in input.segments.iter().enumerate() {
            if idx == 0 {
                total_adjusted_ms += seg.duration_ms;
                breakdowns.push(PcrSegmentBreakdown {
                    segment_index: 1,
                    distance_m: seg.distance_m,
                    raw_duration_ms: seg.duration_ms,
                    rest_before_sec: 0.0,
                    recovery_factor: 0.0,
                    penalty_delta_pct: 0.0,
                    adjusted_duration_ms: seg.duration_ms,
                    note: "Τμήμα 1 (>150m): Καθαρός αγωνιστικός χρόνος (0% ποινή)".to_string(),
                });
            } else {
                let t_sec = (seg.rest_before_ms.max(0) as f64) / 1000.0;
                rest_sum_sec += t_sec;
                rest_count += 1;
                let rec = if t_sec > 0.0 {
                    1.0 - (-t_sec / tau).exp()
                } else {
                    0.0
                };
                let ff = input
                    .custom_ff
                    .unwrap_or(if t_sec >= 20.0 { 0.015 } else { 0.0 });
                // Match Case Study A 4-decimal truncation: 0.13 * 0.510459 + 0.015 = 0.081359 -> 0.0813 (8.13%)
                let delta = ((k * rec + ff) * 10_000.0).floor() / 10_000.0;
                let delta_pct = round2(delta * 100.0);
                let adj_ms = (((seg.duration_ms as f64) * (1.0 + delta)) / 10.0).floor() as i64 * 10;
                total_adjusted_ms += adj_ms;
                last_rec = rec;
                last_delta_pct = delta_pct;
                last_ff = ff;

                breakdowns.push(PcrSegmentBreakdown {
                    segment_index: (idx + 1) as i32,
                    distance_m: seg.distance_m,
                    raw_duration_ms: seg.duration_ms,
                    rest_before_sec: round2(t_sec),
                    recovery_factor: round2(rec * 100.0),
                    penalty_delta_pct: delta_pct,
                    adjusted_duration_ms: adj_ms,
                    note: format!(
                        "Δ = {:.2}% (t={:.0}s, τ={:.0}s, k={:.2}, FF={:.3})",
                        delta_pct, t_sec, tau, k, ff
                    ),
                });
            }
        }

        let missing_m = (input.target_distance_m - swum_distance_m).max(0);
        let extrapolated_tail_ms = if missing_m > 0 {
            if let Some(override_ms) = input.tail_override_ms {
                override_ms.max(0)
            } else {
                let last_seg = breakdowns.last().unwrap();
                let tail_est = (last_seg.adjusted_duration_ms as f64 / last_seg.distance_m as f64)
                    * (missing_m as f64)
                    * 0.9770;
                ((tail_est / 10.0).round() as i64) * 10
            }
        } else {
            0
        };

        if missing_m > 0 {
            breakdowns.push(PcrSegmentBreakdown {
                segment_index: (breakdowns.len() + 1) as i32,
                distance_m: missing_m,
                raw_duration_ms: extrapolated_tail_ms,
                rest_before_sec: 0.0,
                recovery_factor: 0.0,
                penalty_delta_pct: 0.0,
                adjusted_duration_ms: extrapolated_tail_ms,
                note: format!("Εκτίμηση υπολειπόμενων {}m (heavy fatigue)", missing_m),
            });
        }

        let predicted_race_time_ms = total_adjusted_ms + extrapolated_tail_ms;
        let avg_rest_sec = if rest_count > 0 {
            round2(rest_sum_sec / (rest_count as f64))
        } else {
            0.0
        };
        let predicted_pace_ms_per_100m =
            ((predicted_race_time_ms as f64 / input.target_distance_m as f64) * 100.0).round()
                as i64;

        Ok(PcrPredictionResult {
            target_distance_m: input.target_distance_m,
            label: input.label.clone().unwrap_or_else(|| {
                format!(
                    "Πρόβλεψη {}m (Segmented PCr)",
                    input.target_distance_m
                )
            }),
            model_mode: "segmented_pcr".to_string(),
            tau_seconds: tau,
            k_coefficient: k,
            fatigue_factor: last_ff,
            swum_distance_m,
            raw_broken_time_ms,
            average_rest_sec: avg_rest_sec,
            recovery_factor: round2(last_rec * 100.0),
            penalty_delta_pct: last_delta_pct,
            extrapolated_tail_distance_m: missing_m,
            extrapolated_tail_ms,
            predicted_race_time_ms,
            formatted_predicted_time: format_duration_ms(predicted_race_time_ms),
            predicted_pace_ms_per_100m,
            segments: breakdowns,
        })
    } else {
        // Symmetric / Homogeneous Broken Set Mode (e.g. 4x50m -> 200m, 8x50m -> 400m, 4x100m -> 400m)
        let rest_values_sec: Vec<f64> = if input.segments.len() > 1 {
            input.segments[1..]
                .iter()
                .map(|s| (s.rest_before_ms.max(0) as f64) / 1000.0)
                .collect()
        } else {
            vec![(input.segments[0].rest_before_ms.max(0) as f64) / 1000.0]
        };

        let avg_rest_sec = if !rest_values_sec.is_empty() {
            rest_values_sec.iter().sum::<f64>() / (rest_values_sec.len() as f64)
        } else {
            0.0
        };

        let rec = if avg_rest_sec > 0.0 {
            1.0 - (-avg_rest_sec / tau).exp()
        } else {
            0.0
        };

        let ff = input.custom_ff.unwrap_or_else(|| {
            if avg_rest_sec >= 20.0 && input.target_distance_m >= 400 {
                0.015
            } else {
                0.0
            }
        });

        let delta = ((k * rec + ff) * 10_000.0).round() / 10_000.0;
        let delta_pct = round2(delta * 100.0);

        for (idx, seg) in input.segments.iter().enumerate() {
            let t_sec = if idx == 0 {
                0.0
            } else {
                (seg.rest_before_ms.max(0) as f64) / 1000.0
            };
            let seg_adj_ms =
                (((seg.duration_ms as f64) * (1.0 + delta)) / 10.0).round() as i64 * 10;
            breakdowns.push(PcrSegmentBreakdown {
                segment_index: (idx + 1) as i32,
                distance_m: seg.distance_m,
                raw_duration_ms: seg.duration_ms,
                rest_before_sec: round2(t_sec),
                recovery_factor: round2(rec * 100.0),
                penalty_delta_pct: delta_pct,
                adjusted_duration_ms: seg_adj_ms,
                note: format!("Broken Rep #{} (+{:.2}% PCr)", idx + 1, delta_pct),
            });
        }

        let distance_scale = (input.target_distance_m as f64) / (swum_distance_m as f64);
        let predicted_race_time_ms =
            (((raw_broken_time_ms as f64) * distance_scale * (1.0 + delta)) / 10.0).round()
                as i64
                * 10;
        let predicted_pace_ms_per_100m =
            ((predicted_race_time_ms as f64 / input.target_distance_m as f64) * 100.0).round()
                as i64;

        Ok(PcrPredictionResult {
            target_distance_m: input.target_distance_m,
            label: input.label.clone().unwrap_or_else(|| {
                format!(
                    "Πρόβλεψη {}m ({}×{}m Broken)",
                    input.target_distance_m,
                    input.segments.len(),
                    input.segments[0].distance_m
                )
            }),
            model_mode: "symmetric_broken".to_string(),
            tau_seconds: tau,
            k_coefficient: k,
            fatigue_factor: ff,
            swum_distance_m,
            raw_broken_time_ms,
            average_rest_sec: round2(avg_rest_sec),
            recovery_factor: round2(rec * 100.0),
            penalty_delta_pct: delta_pct,
            extrapolated_tail_distance_m: (input.target_distance_m - swum_distance_m).max(0),
            extrapolated_tail_ms: 0,
            predicted_race_time_ms,
            formatted_predicted_time: format_duration_ms(predicted_race_time_ms),
            predicted_pace_ms_per_100m,
            segments: breakdowns,
        })
    }
}

/// Finds the fastest contiguous window of segments whose distances sum to `target_window_m`.
fn find_best_segment_window(
    all_segments: &[PcrSegmentInput],
    target_window_m: i32,
) -> Option<Vec<PcrSegmentInput>> {
    let mut best_window: Option<(i64, Vec<PcrSegmentInput>)> = None;
    for start in 0..all_segments.len() {
        let mut dist_sum = 0i32;
        let mut time_sum = 0i64;
        let mut window = Vec::new();
        for idx in start..all_segments.len() {
            let mut seg = all_segments[idx].clone();
            if window.is_empty() {
                seg.rest_before_ms = 0;
            }
            dist_sum += seg.distance_m;
            time_sum += seg.duration_ms;
            window.push(seg);
            if dist_sum == target_window_m {
                if best_window
                    .as_ref()
                    .map_or(true, |(best_t, _)| time_sum < *best_t)
                {
                    best_window = Some((time_sum, window));
                }
                break;
            }
            if dist_sum > target_window_m {
                break;
            }
        }
    }
    best_window.map(|(_, w)| w)
}

/// Automatically derives Segmented PCr Race Predictions (`200m`, `400m`, `800m`) for a Template
/// using its fastest/latest logged session (or block target durations when no sessions exist yet).
pub fn compute_template_pcr_predictions(
    template: &TemplateWithVersion,
    sessions_chronological_desc: &[SessionWithReps],
) -> Vec<PcrPredictionResult> {
    use crate::engine::expand_template_slots;
    use crate::models::TemplateBlockInput;

    let block_inputs: Vec<TemplateBlockInput> = template
        .active_version
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

    let Ok(slots) = expand_template_slots(template.active_version.rounds, &block_inputs) else {
        return Vec::new();
    };

    // Build segment list from the latest timed session (or from template target durations)
    let latest_timed_session = sessions_chronological_desc
        .iter()
        .find(|s| s.metrics.total_active_duration_ms > 0);

    let mut raw_segments = Vec::new();
    if let Some(session) = latest_timed_session {
        let slot_by_idx: HashMap<i32, &ExpectedRepSlot> =
            slots.iter().map(|s| (s.slot_index, s)).collect();
        let mut prev_rest_ms = 0i64;
        for rep in session.reps.iter().filter(|r| !r.is_skipped) {
            let Some(dist) = rep.distance_m else { continue };
            let Some(dur) = rep.duration_ms else { continue };
            if dist <= 0 || dur <= 0 {
                continue;
            }
            let rest_before = if raw_segments.is_empty() {
                0
            } else {
                prev_rest_ms
            };
            raw_segments.push(PcrSegmentInput {
                distance_m: dist,
                duration_ms: dur,
                rest_before_ms: rest_before,
            });
            prev_rest_ms = rep
                .actual_rest_ms
                .or_else(|| slot_by_idx.get(&rep.slot_index).map(|s| s.rest_or_sendoff_ms))
                .unwrap_or(30_000);
        }
    } else {
        let mut prev_rest_ms = 0i64;
        for slot in &slots {
            let Some(dist) = slot.distance_m else { continue };
            let dur_opt = slot.target_duration_ms.or_else(|| {
                template
                    .active_version
                    .target_pace_ms_per_100m
                    .map(|pace| (pace * (dist as i64)) / 100)
            });
            let Some(dur) = dur_opt else { continue };
            if dist <= 0 || dur <= 0 {
                continue;
            }
            let rest_before = if raw_segments.is_empty() {
                0
            } else {
                prev_rest_ms
            };
            raw_segments.push(PcrSegmentInput {
                distance_m: dist,
                duration_ms: dur,
                rest_before_ms: rest_before,
            });
            prev_rest_ms = match slot.rest_mode {
                RestMode::FixedRest => slot.rest_or_sendoff_ms,
                RestMode::SendOff => (slot.rest_or_sendoff_ms - dur).max(10_000),
            };
        }
    }

    if raw_segments.is_empty() {
        return Vec::new();
    }

    let total_dist: i32 = raw_segments.iter().map(|s| s.distance_m).sum();
    let mut predictions = Vec::new();

    // Case 1: Asymmetric Segmented set starting with > 150m (e.g. Case Study A: 200m + 150m -> 400m)
    if raw_segments[0].distance_m > 150 {
        let target_m = if total_dist <= 400 { 400 } else { total_dist };
        if let Ok(pred) = calculate_pcr_prediction(&PcrRecalculatorInput {
            target_distance_m: target_m,
            label: Some(format!("Πρόβλεψη {}m (Segmented PCr)", target_m)),
            tau_seconds: Some(PCR_TAU_DEFAULT_SEC),
            custom_k: None,
            custom_ff: None,
            tail_override_ms: None,
            segments: raw_segments.clone(),
        }) {
            predictions.push(pred);
        }
        return predictions;
    }

    // Case 2: 200m Prediction (from 4x50m, 2x100m, or best 200m window inside 8x50m / 6x100m / Pyramid)
    if let Some(win_200) = find_best_segment_window(&raw_segments, 200) {
        let label_200 = if win_200.iter().all(|s| s.distance_m == win_200[0].distance_m) {
            format!(
                "Πρόβλεψη 200m ({}×{}m PCr)",
                win_200.len(),
                win_200[0].distance_m
            )
        } else {
            "Πρόβλεψη 200m (Broken 200m PCr)".to_string()
        };
        if let Ok(pred_200) = calculate_pcr_prediction(&PcrRecalculatorInput {
            target_distance_m: 200,
            label: Some(label_200),
            tau_seconds: Some(PCR_TAU_DEFAULT_SEC),
            custom_k: Some(0.16),
            custom_ff: None,
            tail_override_ms: None,
            segments: win_200,
        }) {
            // If the template is pure 200m total (e.g. 4x50m), also add the 400m Oracle extrapolation (200m * 2.17)
            let oracle_400_ms =
                (((pred_200.predicted_race_time_ms as f64) * PCR_ORACLE_200_TO_400_RATIO) / 10.0)
                    .round() as i64
                    * 10;
            predictions.push(pred_200.clone());
            if total_dist < 400 {
                predictions.push(PcrPredictionResult {
                    target_distance_m: 400,
                    label: "Πρόβλεψη 400m (Oracle ×2.17 από 200m)".to_string(),
                    model_mode: "oracle_200_to_400".to_string(),
                    tau_seconds: pred_200.tau_seconds,
                    k_coefficient: 0.13,
                    fatigue_factor: pred_200.fatigue_factor,
                    swum_distance_m: 200,
                    raw_broken_time_ms: pred_200.raw_broken_time_ms,
                    average_rest_sec: pred_200.average_rest_sec,
                    recovery_factor: pred_200.recovery_factor,
                    penalty_delta_pct: pred_200.penalty_delta_pct,
                    extrapolated_tail_distance_m: 200,
                    extrapolated_tail_ms: oracle_400_ms - pred_200.predicted_race_time_ms,
                    predicted_race_time_ms: oracle_400_ms,
                    formatted_predicted_time: format_duration_ms(oracle_400_ms),
                    predicted_pace_ms_per_100m: oracle_400_ms / 4,
                    segments: pred_200.segments,
                });
            }
        }
    }

    // Case 3: 400m Prediction (from 8x50m, 4x100m, or best 400m window inside 6x100m / Pyramid / Compound)
    if let Some(win_400) = find_best_segment_window(&raw_segments, 400) {
        let label_400 = if win_400.iter().all(|s| s.distance_m == win_400[0].distance_m) {
            format!(
                "Πρόβλεψη 400m ({}×{}m PCr)",
                win_400.len(),
                win_400[0].distance_m
            )
        } else {
            "Πρόβλεψη 400m (Broken 400m PCr)".to_string()
        };
        if let Ok(pred_400) = calculate_pcr_prediction(&PcrRecalculatorInput {
            target_distance_m: 400,
            label: Some(label_400),
            tau_seconds: Some(PCR_TAU_DEFAULT_SEC),
            custom_k: Some(0.13),
            custom_ff: None,
            tail_override_ms: None,
            segments: win_400,
        }) {
            predictions.push(pred_400);
        }
    } else if total_dist >= 350 {
        // E.g. 450m Pyramid (50+100+150+100+50): normalize total broken set to 400m with PCr penalty
        if let Ok(pred_400) = calculate_pcr_prediction(&PcrRecalculatorInput {
            target_distance_m: 400,
            label: Some(format!("Πρόβλεψη 400m (από {}m Set)", total_dist)),
            tau_seconds: Some(PCR_TAU_DEFAULT_SEC),
            custom_k: Some(0.13),
            custom_ff: None,
            tail_override_ms: None,
            segments: raw_segments.clone(),
        }) {
            predictions.push(pred_400);
        }
    }

    // Case 4: 800m Prediction if total_dist >= 800m (e.g. 4x[2x50m + 1x100m] = 800m)
    if let Some(win_800) = find_best_segment_window(&raw_segments, 800) {
        if let Ok(pred_800) = calculate_pcr_prediction(&PcrRecalculatorInput {
            target_distance_m: 800,
            label: Some("Πρόβλεψη 800m (Broken 800m PCr)".to_string()),
            tau_seconds: Some(PCR_TAU_DEFAULT_SEC),
            custom_k: Some(0.11),
            custom_ff: None,
            tail_override_ms: None,
            segments: win_800,
        }) {
            predictions.push(pred_800);
        }
    }

    predictions
}

/// Computes the deterministic `HealthContextSummary` (Screen 7 — Health Context & Bevel Rings)
/// from stored `DailyHealthSnapshot` rows ordered by `date_iso DESC`.
/// Obeys the invariant "Unknown != 0": missing metrics remain `None` rather than `0.0`.
pub fn compute_health_context_summary(
    snapshots_desc: &[DailyHealthSnapshot],
) -> HealthContextSummary {
    let sleep_vals: Vec<i32> = snapshots_desc
        .iter()
        .filter_map(|s| s.sleep_duration_minutes)
        .filter(|&v| v > 0)
        .collect();
    let hrv_vals: Vec<f64> = snapshots_desc
        .iter()
        .filter_map(|s| s.hrv_sdnn_ms)
        .filter(|&v| v > 0.0 && v.is_finite())
        .collect();
    let rhr_vals: Vec<f64> = snapshots_desc
        .iter()
        .filter_map(|s| s.resting_hr_bpm)
        .filter(|&v| v > 0.0 && v.is_finite())
        .collect();
    let vo2_vals: Vec<f64> = snapshots_desc
        .iter()
        .filter_map(|s| s.vo2_max_ml_kg_min)
        .filter(|&v| v > 0.0 && v.is_finite())
        .collect();

    let baseline_sleep_minutes = if !sleep_vals.is_empty() {
        let sum: i32 = sleep_vals.iter().sum();
        Some((sum + (sleep_vals.len() as i32 / 2)) / (sleep_vals.len() as i32))
    } else {
        None
    };

    let baseline_hrv_sdnn_ms = if !hrv_vals.is_empty() {
        Some(round2(
            hrv_vals.iter().sum::<f64>() / (hrv_vals.len() as f64),
        ))
    } else {
        None
    };

    let baseline_resting_hr_bpm = if !rhr_vals.is_empty() {
        Some(round2(
            rhr_vals.iter().sum::<f64>() / (rhr_vals.len() as f64),
        ))
    } else {
        None
    };

    let baseline_vo2_max_ml_kg_min = if !vo2_vals.is_empty() {
        Some(round2(
            vo2_vals.iter().sum::<f64>() / (vo2_vals.len() as f64),
        ))
    } else {
        None
    };

    let latest = snapshots_desc.first().cloned();

    let latest_sleep_delta_minutes = match (
        latest.as_ref().and_then(|l| l.sleep_duration_minutes),
        baseline_sleep_minutes,
    ) {
        (Some(cur), Some(base)) => Some(cur - base),
        _ => None,
    };

    let latest_hrv_delta_ms = match (
        latest.as_ref().and_then(|l| l.hrv_sdnn_ms),
        baseline_hrv_sdnn_ms,
    ) {
        (Some(cur), Some(base)) => Some(round2(cur - base)),
        _ => None,
    };

    let latest_rhr_delta_bpm = match (
        latest.as_ref().and_then(|l| l.resting_hr_bpm),
        baseline_resting_hr_bpm,
    ) {
        (Some(cur), Some(base)) => Some(round2(cur - base)),
        _ => None,
    };

    // Bevel Sleep Ring %: relative to 480 min (8h) reference, clamped to 0..=100%
    let bevel_sleep_ring_pct = latest
        .as_ref()
        .and_then(|l| l.sleep_duration_minutes)
        .filter(|&m| m > 0)
        .map(|m| round2(((m as f64 / 480.0) * 100.0).clamp(0.0, 100.0)));

    // Bevel Recovery Context Ring %: relative to personal HRV baseline (75% at baseline, up to 100% when +33% above baseline)
    let bevel_recovery_ring_pct = match (
        latest.as_ref().and_then(|l| l.hrv_sdnn_ms),
        baseline_hrv_sdnn_ms,
    ) {
        (Some(cur), Some(base)) if base > 0.0 && cur > 0.0 => {
            let ratio = cur / base;
            Some(round2((ratio * 78.0).clamp(10.0, 100.0)))
        }
        _ => None,
    };

    HealthContextSummary {
        snapshots_count: snapshots_desc.len(),
        baseline_sleep_minutes,
        baseline_hrv_sdnn_ms,
        baseline_resting_hr_bpm,
        baseline_vo2_max_ml_kg_min,
        latest_snapshot: latest,
        latest_sleep_delta_minutes,
        latest_hrv_delta_ms,
        latest_rhr_delta_bpm,
        bevel_sleep_ring_pct,
        bevel_recovery_ring_pct,
        snapshots: snapshots_desc.to_vec(),
    }
}
