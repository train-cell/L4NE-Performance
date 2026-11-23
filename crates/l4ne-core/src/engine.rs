//! Deterministic Template, Protocol Versioning & Live Poolside Timer Engine (`l4ne_core::engine`).
//!
//! Handles:
//! 1. Slot expansion (`rounds × blocks`) for homogeneous sets, pyramids, and compound sets.
//! 2. Canonical SHA-256 protocol hashing for historical integrity & version control.
//! 3. Athletic Centisecond Numpad parsing (`"3240"` -> `32_400 ms` -> `"32.40"`).
//! 4. Live Poolside Companion (v1.1) deterministic rest & send-off departure countdown clock.

use crate::models::{
    CoreError, EnvironmentType, ExpectedRepSlot, LiveTimerTickInput, LiveTimerTickOutput,
    NumpadParseResult, RestMode, SportCategory, TemplateBlockInput,
};
use sha2::{Digest, Sha256};

/// Maximum allowed repetitions in a single template expansion to prevent accidental DoS inputs.
pub const MAX_TEMPLATE_SLOTS: i32 = 500;

/// Deterministically expands a template protocol (`rounds` and ordered `blocks`)
/// into a 1-based sequence of `ExpectedRepSlot`s.
pub fn expand_template_slots(
    rounds: i32,
    blocks: &[TemplateBlockInput],
) -> Result<Vec<ExpectedRepSlot>, CoreError> {
    if rounds <= 0 {
        return Err(CoreError::Validation(
            "Template rounds must be >= 1".to_string(),
        ));
    }
    if blocks.is_empty() {
        return Err(CoreError::Validation(
            "Template must contain at least one block".to_string(),
        ));
    }

    let mut slots = Vec::new();
    let mut slot_index = 1;

    for round_idx in 1..=rounds {
        for (block_pos, block) in blocks.iter().enumerate() {
            if block.repeat_count <= 0 {
                return Err(CoreError::Validation(format!(
                    "Block {} repeat_count must be >= 1",
                    block_pos
                )));
            }
            if block.rest_or_sendoff_ms < 0 {
                return Err(CoreError::Validation(format!(
                    "Block {} rest_or_sendoff_ms cannot be negative",
                    block_pos
                )));
            }
            if let Some(dist) = block.distance_m {
                if dist <= 0 {
                    return Err(CoreError::Validation(format!(
                        "Block {} distance_m must be > 0 when present",
                        block_pos
                    )));
                }
            }
            if block.stroke_or_movement.trim().is_empty() {
                return Err(CoreError::Validation(format!(
                    "Block {} stroke_or_movement cannot be empty",
                    block_pos
                )));
            }

            for rep_in_block in 1..=block.repeat_count {
                if slot_index > MAX_TEMPLATE_SLOTS {
                    return Err(CoreError::Validation(format!(
                        "Template exceeds maximum allowed slots ({MAX_TEMPLATE_SLOTS})"
                    )));
                }
                slots.push(ExpectedRepSlot {
                    slot_index,
                    round_index: round_idx,
                    block_order: block_pos as i32,
                    rep_within_block: rep_in_block,
                    record_kind: block.record_kind,
                    distance_m: block.distance_m,
                    stroke_or_movement: block.stroke_or_movement.trim().to_lowercase(),
                    rest_mode: block.rest_mode,
                    rest_or_sendoff_ms: block.rest_or_sendoff_ms,
                    target_duration_ms: block.target_duration_ms,
                });
                slot_index += 1;
            }
        }
    }

    Ok(slots)
}

/// Determines whether all expanded slots in a protocol share identical distance, record_kind,
/// and stroke/movement.
pub fn is_homogeneous_protocol(slots: &[ExpectedRepSlot]) -> bool {
    let Some(first) = slots.first() else {
        return true;
    };
    slots.iter().all(|s| {
        s.record_kind == first.record_kind
            && s.distance_m == first.distance_m
            && s.stroke_or_movement == first.stroke_or_movement
    })
}

/// Computes the total distance (in meters) across all expanded slots if all slots have distances.
pub fn compute_total_distance_m(slots: &[ExpectedRepSlot]) -> Option<i32> {
    let mut sum = 0i32;
    let mut has_any = false;
    for slot in slots {
        if let Some(d) = slot.distance_m {
            sum += d;
            has_any = true;
        } else {
            return None;
        }
    }
    if has_any {
        Some(sum)
    } else {
        None
    }
}

/// Computes a deterministic SHA-256 fingerprint of a template's physiological protocol.
pub fn compute_protocol_hash(
    sport_category: SportCategory,
    pool_length_m: Option<i32>,
    environment: EnvironmentType,
    rounds: i32,
    round_rest_ms: i64,
    equipment: &[String],
    blocks: &[TemplateBlockInput],
) -> String {
    let mut normalized_eq: Vec<String> = equipment
        .iter()
        .map(|e| e.trim().to_lowercase())
        .filter(|e| !e.is_empty())
        .collect();
    normalized_eq.sort();
    normalized_eq.dedup();

    let mut canonical = format!(
        "sport={}|pool={:?}|env={}|rounds={}|round_rest={}|eq={}|blocks=",
        sport_category.as_str(),
        pool_length_m,
        environment.as_str(),
        rounds,
        round_rest_ms,
        normalized_eq.join(",")
    );

    for (idx, b) in blocks.iter().enumerate() {
        canonical.push_str(&format!(
            "[#{}:count={},kind={},dist={:?},stroke={},rest_mode={},rest_ms={}];",
            idx,
            b.repeat_count,
            b.record_kind.as_str(),
            b.distance_m,
            b.stroke_or_movement.trim().to_lowercase(),
            b.rest_mode.as_str(),
            b.rest_or_sendoff_ms
        ));
    }

    let mut hasher = Sha256::new();
    hasher.update(canonical.as_bytes());
    let digest = hasher.finalize();
    digest.iter().map(|b| format!("{b:02x}")).collect()
}

/// Parses a sequence of digits entered on the Athletic Centisecond Numpad from left to right into integer milliseconds.
///
/// Left-to-right input rules:
/// - 1 digit (`"3"`): `3` seconds -> `3.00s` (`3_000 ms`)
/// - 2 digits (`"32"`): `32` seconds -> `32.00s` (`32_000 ms`)
/// - 3 digits (`"324"`): `32` seconds + `4` tenths (`40` cs) -> `32.40s` (`32_400 ms`)
/// - 4 digits (`"3240"`): `32` seconds + `40` centiseconds -> `32.40s` (`32_400 ms`)
/// - 5..=7 digits (`"10855"`): `1` minute + `08` seconds + `55` centiseconds -> `1:08.55` (`68_550 ms`)
pub fn parse_athletic_numpad(raw_input: &str) -> Result<NumpadParseResult, CoreError> {
    let digits: String = raw_input
        .chars()
        .filter(|c| !c.is_whitespace())
        .collect();

    if digits.is_empty() {
        return Err(CoreError::Validation(
            "Numpad input cannot be empty".to_string(),
        ));
    }
    if !digits.chars().all(|c| c.is_ascii_digit()) {
        return Err(CoreError::Validation(format!(
            "Numpad input must contain only digits 0-9, got: {raw_input}"
        )));
    }
    if digits.len() > 7 {
        return Err(CoreError::Validation(
            "Numpad input exceeds maximum length (7 digits)".to_string(),
        ));
    }

    let (minutes, seconds, centiseconds): (i64, i64, i64) = match digits.len() {
        1 => {
            let secs: i64 = digits.parse().unwrap_or(0);
            (0, secs, 0)
        }
        2 => {
            let secs: i64 = digits.parse().unwrap_or(0);
            (0, secs, 0)
        }
        3 => {
            let secs: i64 = digits[0..2].parse().unwrap_or(0);
            let tenths: i64 = digits[2..3].parse().unwrap_or(0);
            (0, secs, tenths * 10)
        }
        4 => {
            let secs: i64 = digits[0..2].parse().unwrap_or(0);
            let cs: i64 = digits[2..4].parse().unwrap_or(0);
            (0, secs, cs)
        }
        len => {
            let min_end = len - 4;
            let mins: i64 = digits[0..min_end].parse().unwrap_or(0);
            let secs: i64 = digits[min_end..min_end + 2].parse().unwrap_or(0);
            let cs: i64 = digits[min_end + 2..len].parse().unwrap_or(0);
            if secs >= 60 {
                return Err(CoreError::Validation(format!(
                    "Seconds component ({secs}) must be < 60 when minutes are entered"
                )));
            }
            (mins, secs, cs)
        }
    };

    let duration_ms = (minutes * 60_000) + (seconds * 1_000) + (centiseconds * 10);
    if duration_ms <= 0 {
        return Err(CoreError::Validation(
            "Duration must be greater than 0.00s".to_string(),
        ));
    }

    Ok(NumpadParseResult {
        raw_digits: digits,
        duration_ms,
        formatted_display: format_duration_ms(duration_ms),
    })
}

/// Formats integer milliseconds into standard athletic centisecond notation (`SS.cc` or `M:SS.cc`).
pub fn format_duration_ms(duration_ms: i64) -> String {
    let sign = if duration_ms < 0 { "-" } else { "" };
    let abs_ms = duration_ms.abs();
    let total_centiseconds = (abs_ms + 5) / 10;
    let centiseconds = total_centiseconds % 100;
    let total_seconds = total_centiseconds / 100;
    let minutes = total_seconds / 60;
    let seconds = total_seconds % 60;

    if minutes > 0 {
        format!("{sign}{minutes}:{seconds:02}.{centiseconds:02}")
    } else {
        format!("{sign}{seconds}.{centiseconds:02}")
    }
}

/// Evaluates the Live Poolside Companion (v1.1) state deterministically for any tick.
///
/// - When `rest_elapsed_ms` is `None`: the athlete is currently swimming (`phase = "swimming"`).
///   In `SendOff` mode, if `rep_elapsed_ms > rest_or_sendoff_ms`, flags `"sendoff_overrun"`.
/// - When `rest_elapsed_ms` is `Some(rest_elapsed)`: the athlete has finished the rep and is resting on the wall:
///   - In `FixedRest(R)`: total rest budget is `R`. Remaining rest = `max(0, R - rest_elapsed)`.
///   - In `SendOff(S)`: total rest budget earned is `max(0, S - rep_elapsed_ms)`.
///     Remaining rest = `max(0, (S - rep_elapsed_ms) - rest_elapsed)`.
///   - Generates exact departure cues (`ten_sec_warning`, `five_sec_warning`, `countdown_3_2_1`, `depart_now`).
pub fn evaluate_live_timer_tick(input: &LiveTimerTickInput) -> LiveTimerTickOutput {
    let rep_ms = input.rep_elapsed_ms.max(0);
    let formatted_rep_time = format_duration_ms(rep_ms);

    let Some(rest_elapsed) = input.rest_elapsed_ms else {
        let total_rest_budget = match input.rest_mode {
            RestMode::FixedRest => input.rest_or_sendoff_ms.max(0),
            RestMode::SendOff => (input.rest_or_sendoff_ms - rep_ms).max(0),
        };
        let phase = if input.rest_mode == RestMode::SendOff && rep_ms > input.rest_or_sendoff_ms {
            "sendoff_overrun".to_string()
        } else {
            "swimming".to_string()
        };
        return LiveTimerTickOutput {
            phase,
            formatted_rep_time,
            remaining_rest_ms: total_rest_budget,
            formatted_remaining_rest: format_duration_ms(total_rest_budget),
            audio_cue: "none".to_string(),
            should_auto_advance: false,
        };
    };

    let earned_rest_ms = match input.rest_mode {
        RestMode::FixedRest => input.rest_or_sendoff_ms.max(0),
        RestMode::SendOff => (input.rest_or_sendoff_ms - rep_ms).max(0),
    };

    let remaining_rest_ms = (earned_rest_ms - rest_elapsed.max(0)).max(0);
    let formatted_remaining_rest = format_duration_ms(remaining_rest_ms);

    let (phase, audio_cue, should_auto_advance) = if remaining_rest_ms == 0 {
        ("ready_to_depart".to_string(), "depart_now".to_string(), true)
    } else if remaining_rest_ms <= 3_000 {
        ("resting".to_string(), "countdown_3_2_1".to_string(), false)
    } else if remaining_rest_ms <= 5_000 {
        ("resting".to_string(), "five_sec_warning".to_string(), false)
    } else if remaining_rest_ms <= 10_000 {
        ("resting".to_string(), "ten_sec_warning".to_string(), false)
    } else {
        ("resting".to_string(), "none".to_string(), false)
    };

    LiveTimerTickOutput {
        phase,
        formatted_rep_time,
        remaining_rest_ms,
        formatted_remaining_rest,
        audio_cue,
        should_auto_advance,
    }
}
