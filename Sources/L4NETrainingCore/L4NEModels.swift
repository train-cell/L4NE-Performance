import Foundation

// MARK: - Domain Enums

public struct L4NEEquipmentOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public enum SportCategory: String, Codable, CaseIterable, Sendable {
    case swimming
    case finswimming
    case track
    case field
    case gym

    public var displayTitle: String {
        switch self {
        case .swimming: return "Κλασική Κολύμβηση"
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
            return ["long_jump", "high_jump", "triple_jump", "pole_vault", "shot_put", "discus", "javelin", "hammer"]
        case .gym:
            return ["back_squat", "front_squat", "deadlift", "bench_press", "pull_up", "leg_press"]
        }
    }

    /// Sport-specific equipment catalog for Technical Swimming, Classical Swimming, Track, Field, and Gym.
    public var availableEquipment: [L4NEEquipmentOption] {
        switch self {
        case .finswimming:
            return [
                L4NEEquipmentOption(id: "monofin", title: "Μονοπέδιλο"),
                L4NEEquipmentOption(id: "snorkel", title: "Αναπνευστήρας"),
                L4NEEquipmentOption(id: "mask", title: "Μάσκα"),
                L4NEEquipmentOption(id: "oxygen_tank", title: "Φιάλη Οξυγόνου"),
                L4NEEquipmentOption(id: "bifins", title: "Διπλά Πέδιλα"),
                L4NEEquipmentOption(id: "kickboard", title: "Σανίδα")
            ]
        case .swimming:
            return [
                L4NEEquipmentOption(id: "goggles", title: "Γυαλάκια"),
                L4NEEquipmentOption(id: "paddles", title: "Χεράκια (Paddles)"),
                L4NEEquipmentOption(id: "pullbuoy", title: "Pull Buoy"),
                L4NEEquipmentOption(id: "kickboard", title: "Σανίδα (Kickboard)"),
                L4NEEquipmentOption(id: "swim_fins", title: "Πεδιλάκια Κολύμβησης"),
                L4NEEquipmentOption(id: "center_snorkel", title: "Αναπνευστήρας"),
                L4NEEquipmentOption(id: "parachute", title: "Αλεξίπτωτο Αντίστασης")
            ]
        case .track:
            return [
                L4NEEquipmentOption(id: "spikes", title: "Spikes (Καρφιά)"),
                L4NEEquipmentOption(id: "starting_blocks", title: "Βατήρας Εκκίνησης"),
                L4NEEquipmentOption(id: "hurdles", title: "Εμπόδια (Hurdles)"),
                L4NEEquipmentOption(id: "sled", title: "Έλκηθρο Αντίστασης"),
                L4NEEquipmentOption(id: "baton", title: "Σκυτάλη"),
                L4NEEquipmentOption(id: "racing_flats", title: "Αγωνιστικά Παπούτσια")
            ]
        case .field:
            return [
                L4NEEquipmentOption(id: "field_spikes", title: "Spikes Κονίστρας"),
                L4NEEquipmentOption(id: "shot_put_implement", title: "Σφαίρα"),
                L4NEEquipmentOption(id: "discus_implement", title: "Δίσκος"),
                L4NEEquipmentOption(id: "javelin_implement", title: "Ακόντιο"),
                L4NEEquipmentOption(id: "hammer_implement", title: "Σφύρα"),
                L4NEEquipmentOption(id: "vault_pole", title: "Κοντάρι"),
                L4NEEquipmentOption(id: "takeoff_board", title: "Βαλβίδα Άλματος")
            ]
        case .gym:
            return [
                L4NEEquipmentOption(id: "barbell", title: "Μπάρα (Barbell)"),
                L4NEEquipmentOption(id: "dumbbells", title: "Αλτήρες"),
                L4NEEquipmentOption(id: "lifting_belt", title: "Ζώνη Άρσης Βαρών"),
                L4NEEquipmentOption(id: "straps", title: "Ιμάντες (Straps)"),
                L4NEEquipmentOption(id: "kettlebell", title: "Kettlebell"),
                L4NEEquipmentOption(id: "power_rack", title: "Rack / Μονόζυγο")
            ]
        }
    }

    public var defaultEquipmentIds: Set<String> {
        switch self {
        case .finswimming: return ["monofin", "snorkel", "mask"]
        case .swimming: return ["goggles", "paddles", "pullbuoy"]
        case .track: return ["spikes", "starting_blocks"]
        case .field: return ["field_spikes", "takeoff_board"]
        case .gym: return ["barbell", "lifting_belt"]
        }
    }

    public static func equipmentDisplayTitle(for rawId: String) -> String {
        for cat in SportCategory.allCases {
            if let match = cat.availableEquipment.first(where: { $0.id == rawId }) {
                return match.title
            }
        }
        return rawId.uppercased()
    }

    public var recordEventPresets: [(name: String, distanceM: Int?)] {
        switch self {
        case .finswimming:
            return [
                ("50m Επιφάνεια", 50),
                ("100m Επιφάνεια", 100),
                ("200m Επιφάνεια", 200),
                ("400m Επιφάνεια", 400),
                ("800m Επιφάνεια", 800),
                ("50m Άπνοια", 50),
                ("100m Υποβρύχιο (Φιάλη)", 100),
                ("400m Υποβρύχιο (Φιάλη)", 400),
                ("50m Διπλά Πέδιλα", 50),
                ("100m Διπλά Πέδιλα", 100),
                ("200m Διπλά Πέδιλα", 200),
                ("400m Διπλά Πέδιλα", 400)
            ]
        case .swimming:
            return [
                ("50m Ελεύθερο", 50),
                ("100m Ελεύθερο", 100),
                ("200m Ελεύθερο", 200),
                ("400m Ελεύθερο", 400),
                ("800m Ελεύθερο", 800),
                ("1500m Ελεύθερο", 1500),
                ("50m Πεταλούδα", 50),
                ("100m Πεταλούδα", 100),
                ("50m Ύπτιο", 50),
                ("100m Ύπτιο", 100),
                ("50m Πρόσθιο", 50),
                ("100m Πρόσθιο", 100),
                ("200m Μικτή Ατομική", 200)
            ]
        case .track:
            return [
                ("100m Sprint", 100),
                ("200m Sprint", 200),
                ("400m Sprint", 400),
                ("800m", 800),
                ("1500m", 1500),
                ("110m Εμπόδια", 110),
                ("400m Εμπόδια", 400)
            ]
        case .field:
            return [
                ("Άλμα εις Μήκος", nil),
                ("Άλμα εις Ύψος", nil),
                ("Τριπλούν", nil),
                ("Επί Κοντώ", nil),
                ("Σφαιροβολία", nil),
                ("Ακοντισμός", nil),
                ("Δισκοβολία", nil)
            ]
        case .gym:
            return [
                ("Back Squat 1RM", nil),
                ("Front Squat 1RM", nil),
                ("Deadlift 1RM", nil),
                ("Bench Press 1RM", nil),
                ("Weighted Pull-Up", nil)
            ]
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

/// Multi-Theme Presets (v1.3 Minimalist Graphite / Bevel / Strava Design System).
public enum ThemePreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case graphiteBevel = "graphite_bevel"
    case stravaObsidian = "strava_obsidian"
    case bevelNavy = "bevel_navy"
    case lane4Carbon = "lane4_carbon"
    case minimalAlabaster = "minimal_alabaster"

    public var id: String { rawValue }

    public var displayTitle: String {
        switch self {
        case .graphiteBevel: return "Aquatic Blue"
        case .lane4Carbon: return "Midnight Deep Blue"
        case .bevelNavy: return "Poolside Navy"
        case .stravaObsidian: return "Athletic Red"
        case .minimalAlabaster: return "Daylight Blue"
        }
    }

    public var subtitle: String {
        switch self {
        case .graphiteBevel: return "Αγωνιστικό Μπλε με Cyan & Round Graphite κάρτες"
        case .lane4Carbon: return "Βαθύ Σκούρο Μπλε (Midnight Cobalt) υψηλής αντίθεσης"
        case .bevelNavy: return "Κλασικό Navy Πισίνας με Electric Sky & Gold"
        case .stravaObsidian: return "Ανθρακί με Αγωνιστικό Κόκκινο"
        case .minimalAlabaster: return "Φωτεινό θέμα ημέρας με Royal Blue"
        }
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var activeTheme: ThemePreset
    public var defaultPoolLengthM: Int
    public var preferredSport: SportCategory
    public var hapticsEnabled: Bool
    public var autoAdvanceSendoff: Bool
    public var updatedAtMs: Int64

    public init(
        activeTheme: ThemePreset = .graphiteBevel,
        defaultPoolLengthM: Int = 50,
        preferredSport: SportCategory = .finswimming,
        hapticsEnabled: Bool = true,
        autoAdvanceSendoff: Bool = true,
        updatedAtMs: Int64 = 1_795_356_000_000
    ) {
        self.activeTheme = activeTheme
        self.defaultPoolLengthM = defaultPoolLengthM
        self.preferredSport = preferredSport
        self.hapticsEnabled = hapticsEnabled
        self.autoAdvanceSendoff = autoAdvanceSendoff
        self.updatedAtMs = updatedAtMs
    }
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
    public let pcrPredictions: [PcrPredictionResult]?
}

public struct PcrSegmentInput: Codable, Equatable, Identifiable, Sendable {
    public var id: String { "\(distanceM)-\(durationMs)-\(restBeforeMs)" }
    public var distanceM: Int
    public var durationMs: Int64
    public var restBeforeMs: Int64

    public init(distanceM: Int, durationMs: Int64, restBeforeMs: Int64) {
        self.distanceM = distanceM
        self.durationMs = durationMs
        self.restBeforeMs = restBeforeMs
    }
}

public struct PcrRecalculatorInput: Codable, Equatable, Sendable {
    public var targetDistanceM: Int
    public var label: String?
    public var tauSeconds: Double?
    public var customK: Double?
    public var customFf: Double?
    public var tailOverrideMs: Int64?
    public var segments: [PcrSegmentInput]

    public init(
        targetDistanceM: Int,
        label: String? = nil,
        tauSeconds: Double? = 28.0,
        customK: Double? = nil,
        customFf: Double? = nil,
        tailOverrideMs: Int64? = nil,
        segments: [PcrSegmentInput]
    ) {
        self.targetDistanceM = targetDistanceM
        self.label = label
        self.tauSeconds = tauSeconds
        self.customK = customK
        self.customFf = customFf
        self.tailOverrideMs = tailOverrideMs
        self.segments = segments
    }
}

public struct PcrSegmentBreakdown: Codable, Equatable, Identifiable, Sendable {
    public var id: Int { segmentIndex }
    public let segmentIndex: Int
    public let distanceM: Int
    public let rawDurationMs: Int64
    public let restBeforeSec: Double
    public let recoveryFactor: Double
    public let penaltyDeltaPct: Double
    public let adjustedDurationMs: Int64
    public let note: String
}

public struct PcrPredictionResult: Codable, Equatable, Identifiable, Sendable {
    public var id: String { "\(targetDistanceM)-\(label)" }
    public let targetDistanceM: Int
    public let label: String
    public let modelMode: String
    public let tauSeconds: Double
    public let kCoefficient: Double
    public let fatigueFactor: Double
    public let swumDistanceM: Int
    public let rawBrokenTimeMs: Int64
    public let averageRestSec: Double
    public let recoveryFactor: Double
    public let penaltyDeltaPct: Double
    public let extrapolatedTailDistanceM: Int
    public let extrapolatedTailMs: Int64
    public let predictedRaceTimeMs: Int64
    public let formattedPredictedTime: String
    public let predictedPaceMsPer100m: Int64
    public let segments: [PcrSegmentBreakdown]
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
    public let hasRoute: Bool?
    public let routeSummary: String?
    public let keptAsStandalone: Bool?
    public let associatedTemplatesCount: Int?
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
    public let hasRoute: Bool
    public let routeSummary: String?
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
        hasRoute: Bool = false,
        routeSummary: String? = nil,
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
        self.hasRoute = hasRoute
        self.routeSummary = routeSummary
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

public struct HealthContextSummary: Codable, Equatable, Sendable {
    public let snapshotsCount: Int
    public let baselineSleepMinutes: Int?
    public let baselineHrvSdnnMs: Double?
    public let baselineRestingHrBpm: Double?
    public let baselineVo2MaxMlKgMin: Double?
    public let latestSnapshot: DailyHealthSnapshot?
    public let latestSleepDeltaMinutes: Int?
    public let latestHrvDeltaMs: Double?
    public let latestRhrDeltaBpm: Double?
    public let bevelSleepRingPct: Double?
    public let bevelRecoveryRingPct: Double?
    public let snapshots: [DailyHealthSnapshot]
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

// MARK: - Personal Records & Historical Progression Over Time

public struct CreatePersonalRecordInput: Codable, Equatable, Sendable {
    public var sportCategory: SportCategory
    public var eventName: String
    public var recordKind: RecordKind
    public var poolLengthM: Int?
    public var distanceM: Int?
    public var durationMs: Int64?
    public var valueMetric: Double?
    public var equipment: [String]
    public var competitionOrLocation: String?
    public var achievedAtMs: Int64
    public var notes: String?

    public init(
        sportCategory: SportCategory,
        eventName: String,
        recordKind: RecordKind = .timedDistance,
        poolLengthM: Int? = nil,
        distanceM: Int? = nil,
        durationMs: Int64? = nil,
        valueMetric: Double? = nil,
        equipment: [String] = [],
        competitionOrLocation: String? = nil,
        achievedAtMs: Int64,
        notes: String? = nil
    ) {
        self.sportCategory = sportCategory
        self.eventName = eventName
        self.recordKind = recordKind
        self.poolLengthM = poolLengthM
        self.distanceM = distanceM
        self.durationMs = durationMs
        self.valueMetric = valueMetric
        self.equipment = equipment
        self.competitionOrLocation = competitionOrLocation
        self.achievedAtMs = achievedAtMs
        self.notes = notes
    }
}

public struct PersonalRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let sportCategory: SportCategory
    public let eventName: String
    public let recordKind: RecordKind
    public let poolLengthM: Int?
    public let distanceM: Int?
    public let durationMs: Int64?
    public let formattedValue: String
    public let paceMsPer100m: Int64?
    public let valueMetric: Double?
    public let equipment: [String]
    public let competitionOrLocation: String?
    public let achievedAtMs: Int64
    public let dateIso: String
    public let notes: String?
    public let createdAtMs: Int64
}

public struct EventRecordProgression: Codable, Equatable, Identifiable, Sendable {
    public var id: String { eventKey }
    public let eventKey: String
    public let eventName: String
    public let sportCategory: SportCategory
    public let recordKind: RecordKind
    public let poolLengthM: Int?
    public let distanceM: Int?
    public let entriesCount: Int
    public let personalBest: PersonalRecord
    public let initialRecord: PersonalRecord
    public let latestRecord: PersonalRecord
    public let totalDeltaMs: Int64?
    public let totalImprovementPct: Double
    public let formattedTotalDelta: String
    public let historyChronological: [PersonalRecord]
}
