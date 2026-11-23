//! Deterministic Workout-to-Template Matching Engine (`l4ne_core::matcher`).
//!
//! Evaluates imported Apple HealthKit (`HKWorkout`) or Android Health Connect workouts
//! against the athlete's Templates Library using transparent, deterministic rules.

use crate::models::{
    SessionWithReps, SportCategory, TemplateMatchCandidate, TemplateWithVersion, Workout,
};

/// Returns true if a template's sport category is compatible with an imported workout's sport category.
/// Note: Apple Watch records finswimming (monofin/bifins) under `.swimming`, so an imported
/// `Swimming` workout is deterministically compatible with both `Swimming` and `Finswimming` templates.
pub fn is_sport_compatible(workout_sport: SportCategory, template_sport: SportCategory) -> bool {
    if workout_sport == template_sport {
        return true;
    }
    matches!(
        (workout_sport, template_sport),
        (SportCategory::Swimming, SportCategory::Finswimming)
            | (SportCategory::Finswimming, SportCategory::Swimming)
    )
}

/// Evaluates all non-archived templates against a workout and returns deterministic match candidates
/// sorted by compatibility score descending.
pub fn match_workout_to_templates(
    workout: &Workout,
    templates: &[TemplateWithVersion],
    already_linked_sessions: &[SessionWithReps],
) -> Vec<TemplateMatchCandidate> {
    // Sum distance already assigned to this workout via linked sessions
    let assigned_distance_m: f64 = already_linked_sessions
        .iter()
        .map(|s| {
            s.reps
                .iter()
                .filter(|r| !r.is_skipped)
                .filter_map(|r| r.distance_m.map(|d| d as f64))
                .sum::<f64>()
        })
        .sum();

    let remaining_workout_distance_m = workout
        .total_distance_m
        .map(|total| (total - assigned_distance_m).max(0.0));

    let mut candidates = Vec::new();

    for tpl in templates.iter().filter(|t| !t.is_archived) {
        if !is_sport_compatible(workout.sport_category, tpl.sport_category) {
            continue;
        }

        let mut score = 50; // Base score for matching sport family
        let mut reasons = vec![format!(
            "Sport family compatible ({} ↔ {})",
            workout.sport_category.as_str(),
            tpl.sport_category.as_str()
        )];

        // Rule 2: Pool length check
        let pool_length_matches = match (workout.pool_length_m, tpl.pool_length_m) {
            (Some(w_pool), Some(t_pool)) => {
                if w_pool == t_pool {
                    score += 25;
                    reasons.push(format!("Exact pool length match ({w_pool}m)"));
                    true
                } else {
                    score -= 20;
                    reasons.push(format!(
                        "Pool length mismatch (workout {w_pool}m vs template {t_pool}m)"
                    ));
                    false
                }
            }
            _ => {
                reasons.push("Pool length unspecified on one side".to_string());
                true
            }
        };

        // Rule 3: Template volume fits within remaining workout distance
        let tpl_dist = tpl.active_version.total_distance_m;
        let fits_remaining_distance = match (remaining_workout_distance_m, tpl_dist) {
            (Some(rem), Some(t_d)) => {
                if (t_d as f64) <= rem {
                    score += 25;
                    reasons.push(format!(
                        "Template distance ({t_d}m) fits remaining workout volume ({rem:.0}m)"
                    ));
                    true
                } else {
                    score -= 30;
                    reasons.push(format!(
                        "Template distance ({t_d}m) exceeds remaining workout volume ({rem:.0}m)"
                    ));
                    false
                }
            }
            _ => true,
        };

        candidates.push(TemplateMatchCandidate {
            template_id: tpl.id.clone(),
            template_name: tpl.name.clone(),
            template_version_id: tpl.active_version.id.clone(),
            template_distance_m: tpl_dist,
            pool_length_matches,
            fits_remaining_distance,
            compatibility_score: score,
            deterministic_reasons: reasons,
        });
    }

    candidates.sort_by(|a, b| {
        b.compatibility_score
            .cmp(&a.compatibility_score)
            .then_with(|| a.template_name.cmp(&b.template_name))
    });

    candidates
}
