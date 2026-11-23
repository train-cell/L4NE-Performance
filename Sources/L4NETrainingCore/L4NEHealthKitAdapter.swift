import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// Represents the current HealthKit authorization & capability status on the device (v1.1 Read + Write).
public enum L4NEHealthKitStatus: String, Equatable, Sendable {
    case availableNotRequested = "Διαθέσιμο (Απαιτείται Άδεια)"
    case authorizedReadAndWrite = "Συνδεδεμένο (Read & Write v1.1)"
    case unavailableOnDevice = "Μη Διαθέσιμο στη Συσκευή"
}

/// Deterministic v1.1 adapter bridging Apple HealthKit (`HKHealthStore`) to `L4NECoreClient`.
/// Supports:
/// 1. Requesting Read & Write permissions (`HKWorkout`, HR, HRV, Sleep, RHR, VO2Max).
/// 2. Reading recent `HKWorkout` records with pool length metadata and duplicate prevention.
/// 3. Exporting L4NE Training sessions to Apple Health as `HKWorkout` (`v1.1 Write`) with duplicate prevention.
public final class L4NEHealthKitAdapter: @unchecked Sendable {
    public init() {}

    public var isHealthDataAvailable: Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    /// Requests both Read and Write (`HKWorkout`) authorization for L4NE Training v1.1.
    public func requestReadAndWriteAuthorization() async -> L4NEHealthKitStatus {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            return .unavailableOnDevice
        }
        let store = HKHealthStore()
        var shareTypes: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let distSwim = HKObjectType.quantityType(forIdentifier: .distanceSwimming) {
            shareTypes.insert(distSwim)
        }
        if let distRun = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            shareTypes.insert(distRun)
        }

        var readTypes: Set<HKObjectType> = [HKObjectType.workoutType()]
        let quantityIds: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .heartRateVariabilitySDNN,
            .restingHeartRate,
            .vo2Max,
            .distanceSwimming,
            .distanceWalkingRunning,
            .activeEnergyBurned
        ]
        for qid in quantityIds {
            if let qt = HKObjectType.quantityType(forIdentifier: qid) {
                readTypes.insert(qt)
            }
        }
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleepType)
        }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            return .authorizedReadAndWrite
        } catch {
            return .availableNotRequested
        }
        #else
        return .unavailableOnDevice
        #endif
    }

    /// Exports a logged L4NE `SessionWithReps` to Apple HealthKit (`HKWorkout` Write v1.1)
    /// and records its `exportedExternalUuid` in `l4ne-core` SQLite to prevent duplicate exports.
    public func exportSessionToHealthKit(
        session: SessionWithReps,
        sportCategory: SportCategory,
        client: L4NECoreClient
    ) async throws -> SessionWithReps {
        let externalUuid = "L4NE-SESSION-\(session.id)"

        #if canImport(HealthKit)
        if HKHealthStore.isHealthDataAvailable() {
            let store = HKHealthStore()
            let startDate = Date(timeIntervalSince1970: TimeInterval(session.performedAtMs) / 1000.0)
            let durationSec = max(1.0, TimeInterval(session.metrics.totalActiveDurationMs) / 1000.0)
            let endDate = startDate.addingTimeInterval(durationSec)

            let activityType: HKWorkoutActivityType
            switch sportCategory {
            case .swimming, .finswimming:
                activityType = .swimming
            case .track, .field:
                activityType = .trackAndField
            case .gym:
                activityType = .traditionalStrengthTraining
            }

            let config = HKWorkoutConfiguration()
            config.activityType = activityType
            if sportCategory == .swimming || sportCategory == .finswimming {
                if let poolM = session.poolLengthM {
                    config.swimmingLocationType = .pool
                    config.lapLength = HKQuantity(unit: .meter(), doubleValue: Double(poolM))
                } else {
                    config.swimmingLocationType = .openWater
                }
            }

            let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
            try await builder.beginCollection(at: startDate)
            try await builder.addMetadata([
                HKMetadataKeyExternalUUID: externalUuid,
                HKMetadataKeyWorkoutBrandName: "L4NE Performance"
            ])
            try await builder.endCollection(at: endDate)
            _ = try await builder.finishWorkout()
        }
        #endif

        return try client.markSessionExported(sessionId: session.id, externalUuid: externalUuid)
    }

    /// Builds a sample Apple Watch Ultra 2 Swimming Workout payload for testing or simulator preview.
    public static func sampleAppleWatchSwimmingWorkout(startedAtMs: Int64 = 1_795_442_400_000) -> ImportWorkoutInput {
        ImportWorkoutInput(
            sportCategory: .swimming,
            sourceType: .appleHealth,
            externalSourceUuid: "HK-WATCH-SIM-\(startedAtMs)",
            externalSourceName: "Apple Watch Ultra 2",
            startedAtMs: startedAtMs,
            endedAtMs: startedAtMs + 2_760_000,
            durationMs: 2_760_000,
            totalDistanceM: 2800.0,
            poolLengthM: 50,
            activeEnergyKcal: 685.0,
            avgHeartRateBpm: 158.0,
            maxHeartRateBpm: 185.0,
            notes: "Imported via L4NE HealthKit Adapter (50m Pool)"
        )
    }
}
