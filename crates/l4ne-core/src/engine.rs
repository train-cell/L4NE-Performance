//! Deterministic Template & Protocol Versioning Engine (`l4ne_core::engine`).
//!
//! Handles:
//! 1. Slot expansion (`rounds × blocks`) for homogeneous sets, pyramids, and compound sets.
//! 2. Canonical SHA-256 protocol hashing for historical integrity & version control.
//! 3. Athletic Centisecond Numpad parsing (`"3240"` -> `32_400 ms` -> `"32.40"`).

use crate::models::{
    CoreError, EnvironmentType, ExpectedRepSlot, NumpadParseResult, SportCategory,
    TemplateBlockInput,
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
/// - `true` for homogeneous sets (e.g. `8 × 50m surface`).
/// - `false` for pyramids (e.g. `50-100-150-100-50m`) or multi-stroke compound sets.
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
/// Any change to distance, repetitions, rounds, rest mode/duration, stroke, pool length,
/// or equipment produces a distinct hash, triggering a new `TemplateVersion`.
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

/// Parses a sequence of digits entered on the Athletic Centisecond Numpad into integer milliseconds.
///
/// Format rules (right-to-left positional centisecond encoding: `MMSScc` or `SScc`):
/// - Last 2 digits (`cc`): centiseconds (`00..=99`), each centisecond = `10 ms`.
/// - Next 2 digits (`SS`): seconds (`00..=59`, or up to `99` when <= 4 digits total).
/// - Remaining leading digits (`M` or `MM`): minutes.
///
/// Examples:
/// - `"3240"` -> `32s 40cs` = `32_400 ms` (`"32.40"`)
/// - `"10855"` -> `1m 08s 55cs` = `68_550 ms` (`"1:08.55"`)
/// - `"298"` -> `2s 98cs` = `2_980 ms` (`"2.98"`)
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

    let val: i64 = digits
        .parse()
        .map_err(|_| CoreError::Validation("Invalid digit sequence".to_string()))?;

    let centiseconds = val % 100;
    let total_seconds_part = val / 100;

    let (minutes, seconds) = if digits.len() <= 4 {
        (0, total_seconds_part)
    } else {
        let mins = total_seconds_part / 100;
        let secs = total_seconds_part % 100;
        if secs >= 60 {
            return Err(CoreError::Validation(format!(
                "Seconds component ({secs}) must be < 60 when minutes are entered"
            )));
        }
        (mins, secs)
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
    let total_centiseconds = (abs_ms + 5) / 10; // nearest centisecond
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
