import Foundation

// MARK: - Domain Enums

public enum SportCategory: String, Codable, CaseIterable, Sendable {
    case swimming
    case finswimming
    case track
    case field
    case gym

    public var displayTitle: String {
        switch self {
        case .swimming: return "Κολύμβηση"
        case .finswimming: return "Τεχνική Κολύμβηση"
        case .track: return "Στίβος (Track)"
        case .field: return "Κονίστρα (Field)"
        case .gym: return "Γυμναστήριο (Gym)"
        }
    }

    public var defaultRecordKind: RecordKind {
        switch self {
        case .swimming, .finswimming, .track: return .timedDistance
        case .field: return .distanceAttempt
        case .gym: return .weightReps
        }
    }

    public var availableMovements: [String] {
        switch self {
        case .finswimming:
            return ["surface", "apnea", "immersion", "bifins"]
        case .swimming:
            return ["freestyle", "butterfly", "backstroke", "breaststroke", "im"]
        case .track:
            return ["sprint", "hurdles", "middle_distance", "relay_split"]
        case .field:
            return ["long_jump", "high_jump", "triple_jump", "shot_put", "javelin"]
        case .gym:
            return ["back_squat", "front_squat", "deadlift", "bench_press", "pull_up", "leg_press"]
        }
    }
}

public enum EnvironmentType: String, Codable, CaseIterable, Sendable {
    case pool
    case openWater = "open_water"
    case track
    case gym

    public var displayTitle: String {
        switch self {
        case .pool: return "Πισίνα"
        case .openWater: return "Ανοιχτή Θάλασσα"
        case .track: return "Στίβος"
        case .gym: return "Γυμναστήριο"
        }
    }
}

public enum RecordKind: String, Codable, CaseIterable, Sendable {
    case timedDistance = "timed_distance"
    case distanceAttempt = "distance_attempt"
    case weightReps = "weight_reps"

    public var displayTitle: String {
        switch self {
        case .timedDistance: return "Χρόνος & Απόσταση"
        case .distanceAttempt: return "Απόσταση / Ύψος (m)"
        case .weightReps: return "Βάρος (kg) × Επαναλήψεις"
        }
    }
}

public enum RestMode: String, Codable, CaseIterable, Sendable {
    case fixedRest = "fixed_rest"
    case sendOff = "send_off"

    public var displayTitle: String {
        switch self {
        case .fixedRest: return "Σταθερό Διάλειμμα (Rest)"
        case .sendOff: return "Κύκλος Αναχώρησης (Send-Off)"
        }
    }
}

public enum WorkoutSourceType: String, Codable, CaseIterable, Sendable {
    case manual
    case appleHealth = "apple_health"
    case healthConnect = "health_connect"
}

// MARK: - Template & Protocol Versioning Models

public struct TemplateBlockInput: Codable, Equatable, Sendable {
    public var repeatCount: Int
    public var recordKind: RecordKind
    public var distanceM: Int?
    public var strokeOrMovement: String
    public var restMode: RestMode
    public var restOrSendoffMs: Int64
    public var targetDurationMs: Int64?

    public init(
        repeatCount: Int,
        recordKind: RecordKind = .timedDistance,
        distanceM: Int?,
        strokeOrMovement: String,
        restMode: RestMode,
        restOrSendoffMs: Int64,
        targetDurationMs: Int64? = nil
    ) {
        self.repeatCount = repeatCount
        self.recordKind = recordKind
        self.distanceM = distanceM
        self.strokeOrMovement = strokeOrMovement
        self.restMode = restMode
        self.restOrSendoffMs = restOrSendoffMs
        self.targetDurationMs = targetDurationMs
    }
}

public struct TemplateBlock: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let templateVersionId: String
    public let blockOrder: Int
    public let repeatCount: Int
    public let recordKind: RecordKind
    public let distanceM: Int?
    public let strokeOrMovement: String
    public let restMode: RestMode
    public let restOrSendoffMs: Int64
    public let targetDurationMs: Int64?
}

public struct ExpectedRepSlot: Codable, Equatable, Identifiable, Sendable {
    public var id: Int { slotIndex }
    public let slotIndex: Int
    public let roundIndex: Int
    public let blockOrder: Int
    public let repWithinBlock: Int
    public let recordKind: RecordKind
    public let distanceM: Int?
    public let strokeOrMovement: String
    public let restMode: RestMode
    public let restOrSendoffMs: Int64
    public let targetDurationMs: Int64?
}

public struct TemplateVersion: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let templateId: String
    public let versionNumber: Int
    public let protocolHash: String
    public let rounds: Int
    public let roundRestMs: Int64
    public let equipment: [String]
    public let targetPaceMsPer100m: Int64?
    public let notes: String?
    public let totalReps: Int
    public let totalDistanceM: Int?
    public let isHomogeneous: Bool
    public let blocks: [TemplateBlock]
    public let createdAtMs: Int64
}

public struct TemplateWithVersion: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let sportCategory: SportCategory
    public let poolLengthM: Int?
    public let environment: EnvironmentType
    public let folderTag: String?
    public let isArchived: Bool
    public let activeVersion: TemplateVersion
    public let totalSessionsCount: Int
    public let createdAtMs: Int64
    public let updatedAtMs: Int64
}

public struct CreateTemplateInput: Codable, Sendable {
    public let name: String
    public let sportCategory: SportCategory
    public let poolLengthM: Int?
    public let environment: EnvironmentType
    public let folderTag: String?
    public let rounds: Int
    public let roundRestMs: Int64
    public let equipment: [String]
    public let targetPaceMsPer100m: Int64?
    public let notes: String?
    public let blocks: [TemplateBlockInput]

    public init(
        name: String,
        sportCategory: SportCategory,
        poolLengthM: Int?,
        environment: EnvironmentType = .pool,
        folderTag: String? = nil,
        rounds: Int = 1,
        roundRestMs: Int64 = 0,
        equipment: [String] = [],
        targetPaceMsPer100m: Int64? = nil,
        notes: String? = nil,
        blocks: [TemplateBlockInput]
    ) {
        self.name = name
        self.sportCategory = sportCategory
        self.poolLengthM = poolLengthM
        self.environment = environment
        self.folderTag = folderTag
        self.rounds = rounds
        self.roundRestMs = roundRestMs
        self.equipment = equipment
        self.targetPaceMsPer100m = targetPaceMsPer100m
        self.notes = notes
        self.blocks = blocks
    }
}

public struct UpdateTemplateProtocolInput: Codable, Sendable {
    public let templateId: String
    public let name: String?
    public let poolLengthM: Int?
    public let folderTag: String?
    public let rounds: Int
    public let roundRestMs: Int64
    public let equipment: [String]
    public let targetPaceMsPer100m: Int64?
    public let notes: String?
    public let blocks: [TemplateBlockInput]

    public init(
        templateId: String,
        name: String?,
        poolLengthM: Int?,
        folderTag: String? = nil,
        rounds: Int,
        roundRestMs: Int64,
        equipment: [String],
        targetPaceMsPer100m: Int64?,
        notes: String?,
        blocks: [TemplateBlockInput]
    ) {
        self.templateId = templateId
        self.name = name
        self.poolLengthM = poolLengthM
        self.folderTag = folderTag
        self.rounds = rounds
        self.roundRestMs = roundRestMs
        self.equipment = equipment
        self.targetPaceMsPer100m = targetPaceMsPer100m
        self.notes = notes
        self.blocks = blocks
    }
}

// MARK: - Sessions, Reps & Deterministic Analytics Models (v1.1 Multi-Sport)

public struct RepInput: Codable, Equatable, Sendable {
    public let slotIndex: Int
    public let durationMs: Int64?
    public let strokeCount: Int?
    public let rpe: Int?
    public let weightKg: Double?
    public let repsCompleted: Int?
    public let attemptResultM: Double?
    public let splitsMs: [Int64]
    public let isSkipped: Bool
    public let notes: String?

    public init(
        slotIndex: Int,
        durationMs: Int64?,
        strokeCount: Int? = nil,
        rpe: Int? = nil,
        weightKg: Double? = nil,
        repsCompleted: Int? = nil,
        attemptResultM: Double? = nil,
        splitsMs: [Int64] = [],
        isSkipped: Bool = false,
        notes: String? = nil
    ) {
        self.slotIndex = slotIndex
        self.durationMs = durationMs
        self.strokeCount = strokeCount
        self.rpe = rpe
        self.weightKg = weightKg
        self.repsCompleted = repsCompleted
        self.attemptResultM = attemptResultM
        self.splitsMs = splitsMs
        self.isSkipped = isSkipped
        self.notes = notes
    }
}

public struct LogSessionInput: Codable, Sendable {
    public let templateId: String
    public let templateVersionId: String?
    public let workoutId: String?
    public let performedAtMs: Int64
    public let poolLengthM: Int?
    public let notes: String?
    public let reps: [RepInput]

    public init(
        templateId: String,
        templateVersionId: String? = nil,
        workoutId: String? = nil,
        performedAtMs: Int64,
        poolLengthM: Int? = nil,
        notes: String? = nil,
        reps: [RepInput]
    ) {
        self.templateId = templateId
        self.templateVersionId = templateVersionId
        self.workoutId = workoutId
        self.performedAtMs = performedAtMs
        self.poolLengthM = poolLengthM
        self.notes = notes
        self.reps = reps
    }
}

public struct RepRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let sessionId: String
    public let slotIndex: Int
    public let roundIndex: Int
    public let blockOrder: Int
    public let distanceM: Int?
    public let durationMs: Int64?
    public let paceMsPer100m: Int64?
    public let actualRestMs: Int64?
    public let strokeCount: Int?
    public let swolfScore: Int?
    public let rpe: Int?
    public let weightKg: Double?
    public let repsCompleted: Int?
    public let attemptResultM: Double?
    public let splitsMs: [Int64]?
    public let isSkipped: Bool
    public let notes: String?
}

public struct SessionSummaryMetrics: Codable, Equatable, Sendable {
    public let totalActiveDurationMs: Int64
    public let avgDurationMs: Int64?
    public let bestRepDurationMs: Int64?
    public let worstRepDurationMs: Int64?
    public let avgPaceMsPer100m: Int64?
    public let stdDevMs: Double?
    public let consistencyCvPct: Double?
    public let fatigueIndexPct: Double?
    public let totalTonnageKg: Double?
    public let bestEstimated1RmKg: Double?
    public let bestAttemptM: Double?
}

public struct SessionWithReps: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let templateId: String
    public let templateName: String
    public let templateVersionId: String
    public let templateVersionNumber: Int
    public let protocolHash: String
    public let isHomogeneous: Bool
    public let workoutId: String?
    public let exportedExternalUuid: String?
    public let performedAtMs: Int64
    public let poolLengthM: Int?
    public let isCompleted: Bool
    public let notes: String?
    public let metrics: SessionSummaryMetrics
    public let reps: [RepRecord]
    public let createdAtMs: Int64
}

public struct SlotDelta: Codable, Equatable, Identifiable, Sendable {
    public var id: Int { slotIndex }
    public let slotIndex: Int
    public let distanceM: Int?
    public let currentDurationMs: Int64?
    public let baselineDurationMs: Int64?
    public let deltaMs: Int64?
    public let improvementPct: Double?
}

public struct SessionComparison: Codable, Equatable, Sendable {
    public let currentSessionId: String
    public let baselineSessionId: String
    public let protocolCompatible: Bool
    public let currentVersionNumber: Int
    public let baselineVersionNumber: Int
    public let protocolWarning: String?
    public let totalDurationDeltaMs: Int64
    public let totalImprovementPct: Double
    public let paceDeltaMsPer100m: Int64?
    public let paceImprovementPct: Double?
    public let consistencyDeltaMs: Double?
    public let slotDeltas: [SlotDelta]
}

public struct SessionHealthCorrelationNote: Codable, Equatable, Identifiable, Sendable {
    public var id: String { sessionId }
    public let sessionId: String
    public let dateIso: String
    public let avgPaceMsPer100m: Int64?
    public let sleepDurationMinutes: Int?
    public let hrvSdnnMs: Double?
    public let restingHrBpm: Double?
    public let observationalNote: String
}

public struct TemplateAnalyticsReport: Codable, Equatable, Sendable {
    public let templateId: String
    public let templateName: String
    public let activeVersionNumber: Int
    public let totalSessions: Int
    public let personalBestSessionId: String?
    public let personalBestTotalDurationMs: Int64?
    public let personalBestAvgDurationMs: Int64?
    public let personalBestRepDurationMs: Int64?
    public let personalBestPaceMsPer100m: Int64?
    public let personalBestTonnageKg: Double?
    public let personalBest1RmKg: Double?
    public let personalBestAttemptM: Double?
    public let latestVsPrevious: SessionComparison?
    public let latestVsPersonalBest: SessionComparison?
    public let healthCorrelations: [SessionHealthCorrelationNote]
}

// MARK: - Workouts, HealthKit Matching & Timeline Models

public struct Workout: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let sportCategory: SportCategory
    public let sourceType: WorkoutSourceType
    public let externalSourceUuid: String?
    public let externalSourceName: String?
    public let startedAtMs: Int64
    public let endedAtMs: Int64?
    public let durationMs: Int64?
    public let totalDistanceM: Double?
    public let poolLengthM: Int?
    public let activeEnergyKcal: Double?
    public let avgHeartRateBpm: Double?
    public let maxHeartRateBpm: Double?
    public let lapDurationsMs: [Int64]?
    public let notes: String?
    public let createdAtMs: Int64
}

public struct ImportWorkoutInput: Codable, Sendable {
    public let sportCategory: SportCategory
    public let sourceType: WorkoutSourceType
    public let externalSourceUuid: String?
    public let externalSourceName: String?
    public let startedAtMs: Int64
    public let endedAtMs: Int64?
    public let durationMs: Int64?
    public let totalDistanceM: Double?
    public let poolLengthM: Int?
    public let activeEnergyKcal: Double?
    public let avgHeartRateBpm: Double?
    public let maxHeartRateBpm: Double?
    public let lapDurationsMs: [Int64]
    public let notes: String?

    public init(
        sportCategory: SportCategory,
        sourceType: WorkoutSourceType,
        externalSourceUuid: String?,
        externalSourceName: String?,
        startedAtMs: Int64,
        endedAtMs: Int64? = nil,
        durationMs: Int64?,
        totalDistanceM: Double?,
        poolLengthM: Int?,
        activeEnergyKcal: Double? = nil,
        avgHeartRateBpm: Double? = nil,
        maxHeartRateBpm: Double? = nil,
        lapDurationsMs: [Int64] = [],
        notes: String? = nil
    ) {
        self.sportCategory = sportCategory
        self.sourceType = sourceType
        self.externalSourceUuid = externalSourceUuid
        self.externalSourceName = externalSourceName
        self.startedAtMs = startedAtMs
        self.endedAtMs = endedAtMs
        self.durationMs = durationMs
        self.totalDistanceM = totalDistanceM
        self.poolLengthM = poolLengthM
        self.activeEnergyKcal = activeEnergyKcal
        self.avgHeartRateBpm = avgHeartRateBpm
        self.maxHeartRateBpm = maxHeartRateBpm
        self.lapDurationsMs = lapDurationsMs
        self.notes = notes
    }
}

public struct TemplateMatchCandidate: Codable, Equatable, Identifiable, Sendable {
    public var id: String { templateId }
    public let templateId: String
    public let templateName: String
    public let templateVersionId: String
    public let templateDistanceM: Int?
    public let poolLengthMatches: Bool
    public let fitsRemainingDistance: Bool
    public let compatibilityScore: Int
    public let deterministicReasons: [String]
}

public struct DailyHealthSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: String { dateIso }
    public let dateIso: String
    public let sleepDurationMinutes: Int?
    public let hrvSdnnMs: Double?
    public let restingHrBpm: Double?
    public let vo2MaxMlKgMin: Double?
    public let sourceSummary: String?
    public let capturedAtMs: Int64

    public init(
        dateIso: String,
        sleepDurationMinutes: Int?,
        hrvSdnnMs: Double?,
        restingHrBpm: Double?,
        vo2MaxMlKgMin: Double?,
        sourceSummary: String?,
        capturedAtMs: Int64
    ) {
        self.dateIso = dateIso
        self.sleepDurationMinutes = sleepDurationMinutes
        self.hrvSdnnMs = hrvSdnnMs
        self.restingHrBpm = restingHrBpm
        self.vo2MaxMlKgMin = vo2MaxMlKgMin
        self.sourceSummary = sourceSummary
        self.capturedAtMs = capturedAtMs
    }
}

public struct DailyTrainingTimeline: Codable, Equatable, Sendable {
    public let dateIso: String
    public let workouts: [Workout]
    public let standaloneAndLinkedSessions: [SessionWithReps]
    public let totalVolumeDistanceM: Double
    public let totalDurationMs: Int64
    public let healthSnapshot: DailyHealthSnapshot?
}

public struct NumpadParseResult: Codable, Equatable, Sendable {
    public let rawDigits: String
    public let durationMs: Int64
    public let formattedDisplay: String
}

// MARK: - v1.1 Live Poolside Companion, Backup Restore & Database Diagnostics

public struct LiveTimerTickInput: Codable, Equatable, Sendable {
    public let restMode: RestMode
    public let restOrSendoffMs: Int64
    public let repElapsedMs: Int64
    public let restElapsedMs: Int64?

    public init(
        restMode: RestMode,
        restOrSendoffMs: Int64,
        repElapsedMs: Int64,
        restElapsedMs: Int64?
    ) {
        self.restMode = restMode
        self.restOrSendoffMs = restOrSendoffMs
        self.repElapsedMs = repElapsedMs
        self.restElapsedMs = restElapsedMs
    }
}

public struct LiveTimerTickOutput: Codable, Equatable, Sendable {
    public let phase: String
    public let formattedRepTime: String
    public let remainingRestMs: Int64
    public let formattedRemainingRest: String
    public let audioCue: String
    public let shouldAutoAdvance: Bool
}

public struct RestoreBackupResult: Codable, Equatable, Sendable {
    public let templatesRestored: Int
    public let workoutsRestored: Int
    public let sessionsRestored: Int
    public let healthSnapshotsRestored: Int
}

public struct DatabaseDiagnostics: Codable, Equatable, Sendable {
    public let engineVersion: String
    public let schemaVersion: Int
    public let templatesCount: Int
    public let templateVersionsCount: Int
    public let sessionsCount: Int
    public let repRecordsCount: Int
    public let workoutsCount: Int
    public let healthSnapshotsCount: Int
}
