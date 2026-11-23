//! Deterministic Performance Analytics Engine (`l4ne_core::analytics`).
//!
//! 100% mathematical & deterministic calculations — zero AI, zero heuristics.
//! Supports:
//! - Homogeneous & Pyramid/Compound sets for Swimming, Finswimming, and Track (`timed_distance`)
//! - Field Throws & Jumps (`distance_attempt`: best attempt, average, progression)
//! - Gym Strength Training (`weight_reps`: total tonnage kg, Epley estimated 1RM kg, average RPE)

use crate::models::{
    DailyHealthSnapshot, ExpectedRepSlot, RepRecord, RestMode, SessionComparison,
    SessionHealthCorrelationNote, SessionSummaryMetrics, SessionWithReps, SlotDelta,
    TemplateAnalyticsReport, TemplateWithVersion,
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
    }
}
