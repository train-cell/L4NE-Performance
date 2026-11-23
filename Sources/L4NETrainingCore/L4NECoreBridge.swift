import Foundation
#if canImport(L4NECoreFFI)
import L4NECoreFFI
#endif

public enum L4NECoreError: Error, LocalizedError, Equatable, Sendable {
    case rustEngineError(String)
    case encodingError(String)
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case .rustEngineError(let msg): return msg
        case .encodingError(let msg): return "Encoding error: \(msg)"
        case .decodingError(let msg): return "Decoding error: \(msg)"
        }
    }
}

private struct FFIEnvelope<T: Decodable>: Decodable {
    let ok: Bool
    let data: T?
    let error: String?
}

public struct L4NEInitResult: Codable, Equatable, Sendable {
    public let seeded: Bool
    public let templatesCount: Int
    public let engineVersion: String
}

/// Deterministic formatting utilities for athletic durations and paces.
public enum L4NEDurationFormatter {
    public static func formatMs(_ durationMs: Int64, includeUnit: Bool = true) -> String {
        let sign = durationMs < 0 ? "-" : ""
        let absMs = abs(durationMs)
        let totalCentiseconds = (absMs + 5) / 10
        let centiseconds = totalCentiseconds % 100
        let totalSeconds = totalCentiseconds / 100
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes > 0 {
            return String(format: "%@%lld:%02lld.%02lld", sign, minutes, seconds, centiseconds)
        } else {
            let suffix = includeUnit ? "s" : ""
            return String(format: "%@%lld.%02lld%@", sign, seconds, centiseconds, suffix)
        }
    }

    public static func formatPacePer100m(_ paceMs: Int64) -> String {
        "\(formatMs(paceMs, includeUnit: false)) /100m"
    }

    public static func formatIntervalMs(_ ms: Int64) -> String {
        let totalSeconds = ms / 1000
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        if mins > 0 {
            return String(format: "%lld:%02lld", mins, secs)
        } else {
            return "\(secs)s"
        }
    }

    public static func formatEpochDate(_ epochMs: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epochMs) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
}

/// Direct Swift 6 FFI Client (v1.1) backed by the compiled Rust library (`libl4ne_core.a`).
public final class L4NECoreClient: @unchecked Sendable {
    public let databasePath: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(databasePath: String) {
        self.databasePath = databasePath
        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = enc

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = dec
    }

    /// Returns the semantic version of the linked `l4ne-core` Rust engine ("1.1.0").
    public static var engineVersion: String {
        guard let cPtr = l4ne_core_version() else { return "1.1.0" }
        return String(cString: cPtr)
    }

    /// Initializes and migrates the local SQLite database to schema v2.
    @discardableResult
    public func initializeDatabase(seedDemoIfEmpty: Bool = true) throws -> L4NEInitResult {
        let rawJson: String = databasePath.withCString { pathPtr in
            guard let resPtr = l4ne_init_database_json(pathPtr, seedDemoIfEmpty) else {
                return #"{"ok":false,"error":"Null pointer returned from l4ne_init_database_json"}"#
            }
            defer { l4ne_string_free(resPtr) }
            return String(cString: resPtr)
        }
        return try decodeEnvelope(from: rawJson)
    }

    /// Parses raw digit input from the Athletic Centisecond Numpad using Rust's deterministic parser.
    public func parseAthleticNumpad(digits: String) throws -> NumpadParseResult {
        struct Request: Encodable {
            let action = "parse_numpad"
            let digits: String
        }
        return try execute(Request(digits: digits))
    }

    /// Evaluates a Live Poolside Companion (v1.1) clock tick deterministically inside Rust.
    public func computeLiveTimerTick(_ input: LiveTimerTickInput) throws -> LiveTimerTickOutput {
        struct Request: Encodable {
            let action = "compute_live_timer_tick"
            let payload: LiveTimerTickInput
        }
        return try execute(Request(payload: input))
    }

    /// Lists Templates with their active `TemplateVersion` and blocks.
    public func listTemplates(includeArchived: Bool = false) throws -> [TemplateWithVersion] {
        struct Request: Encodable {
            let action = "list_templates"
            let includeArchived: Bool
        }
        return try execute(Request(includeArchived: includeArchived))
    }

    /// Retrieves a single Template by ID.
    public func getTemplate(id: String) throws -> TemplateWithVersion {
        struct Request: Encodable {
            let action = "get_template"
            let templateId: String
        }
        return try execute(Request(templateId: id))
    }

    /// Lists all historical protocol versions (`v1..vN`) of a template.
    public func listTemplateVersions(templateId: String) throws -> [TemplateVersion] {
        struct Request: Encodable {
            let action = "list_template_versions"
            let templateId: String
        }
        return try execute(Request(templateId: templateId))
    }

    /// Creates a new Template with its initial `TemplateVersion (v1)`.
    public func createTemplate(_ input: CreateTemplateInput, nowMs: Int64? = nil) throws -> TemplateWithVersion {
        struct Request: Encodable {
            let action = "create_template"
            let payload: CreateTemplateInput
            let nowMs: Int64?
        }
        return try execute(Request(payload: input, nowMs: nowMs))
    }

    /// Updates a Template's protocol; mints a new `TemplateVersion` (`v+1`) if the protocol hash changes.
    public func updateTemplateProtocol(_ input: UpdateTemplateProtocolInput, nowMs: Int64? = nil) throws -> TemplateWithVersion {
        struct Request: Encodable {
            let action = "update_template_protocol"
            let payload: UpdateTemplateProtocolInput
            let nowMs: Int64?
        }
        return try execute(Request(payload: input, nowMs: nowMs))
    }

    /// Archives or unarchives a Template without modifying historical sessions.
    public func setTemplateArchived(templateId: String, isArchived: Bool, nowMs: Int64? = nil) throws -> TemplateWithVersion {
        struct Request: Encodable {
            let action = "set_template_archived"
            let templateId: String
            let isArchived: Bool
            let nowMs: Int64?
        }
        return try execute(Request(templateId: templateId, isArchived: isArchived, nowMs: nowMs))
    }

    /// Expands a `TemplateVersion` into its deterministic sequence of `ExpectedRepSlot`s.
    public func expandTemplateSlots(templateVersionId: String) throws -> [ExpectedRepSlot] {
        struct Request: Encodable {
            let action = "expand_template_slots"
            let templateVersionId: String
        }
        return try execute(Request(templateVersionId: templateVersionId))
    }

    /// Logs a completed session and returns the stored session with deterministically computed metrics.
    public func logSession(_ input: LogSessionInput, nowMs: Int64? = nil) throws -> SessionWithReps {
        struct Request: Encodable {
            let action = "log_session"
            let payload: LogSessionInput
            let nowMs: Int64?
        }
        return try execute(Request(payload: input, nowMs: nowMs))
    }

    /// Deletes a session and its repetitions.
    @discardableResult
    public func deleteSession(sessionId: String) throws -> Bool {
        struct Request: Encodable {
            let action = "delete_session"
            let sessionId: String
        }
        struct Response: Decodable {
            let deleted: Bool
        }
        let res: Response = try execute(Request(sessionId: sessionId))
        return res.deleted
    }

    /// Links (or unlinks) a logged session to an imported Apple HealthKit / manual workout.
    public func linkSessionToWorkout(sessionId: String, workoutId: String?) throws -> SessionWithReps {
        struct Request: Encodable {
            let action = "link_session_to_workout"
            let sessionId: String
            let workoutId: String?
        }
        return try execute(Request(sessionId: sessionId, workoutId: workoutId))
    }

    /// Marks a session as exported to Apple HealthKit (`HKWorkout`), preventing duplicate exports.
    public func markSessionExported(sessionId: String, externalUuid: String) throws -> SessionWithReps {
        struct Request: Encodable {
            let action = "mark_session_exported"
            let sessionId: String
            let externalUuid: String
        }
        return try execute(Request(sessionId: sessionId, externalUuid: externalUuid))
    }

    /// Lists sessions (optionally filtered by `templateId`).
    public func listSessions(templateId: String? = nil) throws -> [SessionWithReps] {
        struct Request: Encodable {
            let action = "list_sessions"
            let templateId: String?
        }
        return try execute(Request(templateId: templateId))
    }

    /// Computes the full deterministic `TemplateAnalyticsReport` for a template.
    public func getTemplateAnalytics(templateId: String) throws -> TemplateAnalyticsReport {
        struct Request: Encodable {
            let action = "template_analytics"
            let templateId: String
        }
        return try execute(Request(templateId: templateId))
    }

    /// Compares two sessions (`current` vs `baseline`) slot-by-slot and in aggregate.
    public func compareSessions(currentSessionId: String, baselineSessionId: String) throws -> SessionComparison {
        struct Request: Encodable {
            let action = "compare_sessions"
            let currentSessionId: String
            let baselineSessionId: String
        }
        return try execute(Request(currentSessionId: currentSessionId, baselineSessionId: baselineSessionId))
    }

    /// Imports an Apple HealthKit or manual workout with duplicate UUID protection.
    public func importWorkout(_ input: ImportWorkoutInput, nowMs: Int64? = nil) throws -> Workout {
        struct Request: Encodable {
            let action = "import_workout"
            let payload: ImportWorkoutInput
            let nowMs: Int64?
        }
        return try execute(Request(payload: input, nowMs: nowMs))
    }

    /// Lists all imported and manual workouts.
    public func listWorkouts() throws -> [Workout] {
        struct Request: Encodable {
            let action = "list_workouts"
        }
        return try execute(Request())
    }

    /// Runs deterministic workout-to-template matching for an imported workout.
    public func matchWorkoutTemplates(workoutId: String) throws -> [TemplateMatchCandidate] {
        struct Request: Encodable {
            let action = "match_workout_templates"
            let workoutId: String
        }
        return try execute(Request(workoutId: workoutId))
    }

    /// v1.2: Deterministically pre-fills `RepInput` records for a template version from Apple Watch lap events.
    public func prefillRepsFromWorkoutLaps(workoutId: String, templateVersionId: String) throws -> [RepInput] {
        struct Request: Encodable {
            let action = "prefill_reps_from_workout_laps"
            let workoutId: String
            let templateVersionId: String
        }
        return try execute(Request(workoutId: workoutId, templateVersionId: templateVersionId))
    }

    /// Upserts a daily health snapshot (`YYYY-MM-DD`).
    @discardableResult
    public func upsertHealthSnapshot(_ snapshot: DailyHealthSnapshot) throws -> DailyHealthSnapshot {
        struct Request: Encodable {
            let action = "upsert_health_snapshot"
            let payload: DailyHealthSnapshot
        }
        return try execute(Request(payload: snapshot))
    }

    /// Lists all stored daily health snapshots.
    public func listHealthSnapshots() throws -> [DailyHealthSnapshot] {
        struct Request: Encodable {
            let action = "list_health_snapshots"
        }
        return try execute(Request())
    }

    /// Fetches the unified Daily Training Timeline for a specific `YYYY-MM-DD`.
    public func getDailyTimeline(dateIso: String) throws -> DailyTrainingTimeline {
        struct Request: Encodable {
            let action = "daily_timeline"
            let dateIso: String
        }
        return try execute(Request(dateIso: dateIso))
    }

    /// Exports the entire local SQLite database as a portable JSON backup string.
    public func exportBackupJSON(nowMs: Int64? = nil) throws -> String {
        struct Request: Encodable {
            let action = "export_json"
            let nowMs: Int64?
        }
        struct Response: Decodable {
            let json: String
        }
        let resp: Response = try execute(Request(nowMs: nowMs))
        return resp.json
    }

    /// Restores a portable JSON backup string idempotently into the local SQLite database.
    public func importBackupJSON(_ backupJson: String) throws -> RestoreBackupResult {
        struct Request: Encodable {
            let action = "import_json"
            let backupJson: String
        }
        return try execute(Request(backupJson: backupJson))
    }

    /// Exports all logged sessions and repetitions as a CSV string.
    public func exportSessionsCSV() throws -> String {
        struct Request: Encodable {
            let action = "export_csv"
        }
        struct Response: Decodable {
            let csv: String
        }
        let resp: Response = try execute(Request())
        return resp.csv
    }

    /// Returns diagnostic counts of all tables in the local SQLite database.
    public func getDatabaseDiagnostics() throws -> DatabaseDiagnostics {
        struct Request: Encodable {
            let action = "database_stats"
        }
        return try execute(Request())
    }

    // MARK: - Private FFI Execution Helpers

    private func execute<Req: Encodable, Res: Decodable>(_ request: Req) throws -> Res {
        let reqData: Data
        do {
            reqData = try encoder.encode(request)
        } catch {
            throw L4NECoreError.encodingError(error.localizedDescription)
        }
        guard let reqString = String(data: reqData, encoding: .utf8) else {
            throw L4NECoreError.encodingError("Unable to encode request as UTF-8")
        }

        let rawResponse: String = databasePath.withCString { dbPtr in
            reqString.withCString { reqPtr in
                guard let resPtr = l4ne_execute_json(dbPtr, reqPtr) else {
                    return #"{"ok":false,"error":"Null pointer returned from l4ne_execute_json"}"#
                }
                defer { l4ne_string_free(resPtr) }
                return String(cString: resPtr)
            }
        }
        return try decodeEnvelope(from: rawResponse)
    }

    private func decodeEnvelope<Res: Decodable>(from jsonString: String) throws -> Res {
        guard let data = jsonString.data(using: .utf8) else {
            throw L4NECoreError.decodingError("Invalid UTF-8 response from Rust core")
        }
        let envelope: FFIEnvelope<Res>
        do {
            envelope = try decoder.decode(FFIEnvelope<Res>.self, from: data)
        } catch {
            throw L4NECoreError.decodingError("\(error.localizedDescription) in payload: \(jsonString)")
        }
        if envelope.ok, let value = envelope.data {
            return value
        } else {
            throw L4NECoreError.rustEngineError(envelope.error ?? "Unknown l4ne-core error")
        }
    }
}
