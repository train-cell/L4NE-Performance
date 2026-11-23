import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// Represents the current HealthKit authorization & capability status on the device.
public enum L4NEHealthKitStatus: String, Equatable, Sendable {
    case availableNotRequested = "Διαθέσιμο (Απαιτείται Άδεια)"
    case authorizedRead = "Συνδεδεμένο (Read-Only v1.0)"
    case unavailableOnDevice = "Μη Διαθέσιμο στη Συσκευή"
}

/// Deterministic adapter bridging Apple HealthKit (`HKHealthStore`) to `L4NECoreClient`.
/// Handles missing metrics gracefully without crashing or fabricating values.
public final class L4NEHealthKitAdapter: @unchecked Sendable {
    public init() {}

    public var isHealthDataAvailable: Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    /// Requests read-only authorization for Swimming/Track/Gym workouts, Heart Rate, Sleep, HRV, Resting HR, and VO2 Max.
    public func requestReadAuthorization() async -> L4NEHealthKitStatus {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            return .unavailableOnDevice
        }
        let store = HKHealthStore()
        var readTypes: Set<HKObjectType> = [HKObjectType.workoutType()]
        let quantityIds: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .heartRateVariabilitySDNN,
            .restingHeartRate,
            .vo2Max,
            .distanceSwimming,
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
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return .authorizedRead
        } catch {
            return .availableNotRequested
        }
        #else
        return .unavailableOnDevice
        #endif
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
