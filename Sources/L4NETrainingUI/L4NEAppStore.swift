import Foundation
import SwiftUI
#if canImport(L4NETrainingCore)
import L4NETrainingCore
#endif

/// Main Observable ViewModel coordinating local SQLite state through `L4NECoreClient`.
@MainActor
public final class L4NEAppStore: ObservableObject {
    public let client: L4NECoreClient
    public let healthKitAdapter = L4NEHealthKitAdapter()

    @Published public var templates: [TemplateWithVersion] = []
    @Published public var recentSessions: [SessionWithReps] = []
    @Published public var workouts: [Workout] = []
    @Published public var healthSnapshots: [DailyHealthSnapshot] = []
    @Published public var selectedTimelineDateIso: String = "2026-11-22"
    @Published public var currentTimeline: DailyTrainingTimeline?
    @Published public var healthKitStatus: L4NEHealthKitStatus = .availableNotRequested
    @Published public var lastErrorMessage: String?
    @Published public var lastExportPreview: String?

    public init(databasePath: String? = nil) {
        let resolvedPath: String
        if let databasePath {
            resolvedPath = databasePath
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            resolvedPath = docs.appendingPathComponent("l4ne_training_v1.sqlite").path
        }
        self.client = L4NECoreClient(databasePath: resolvedPath)
        self.bootstrap()
    }

    public func bootstrap() {
        do {
            _ = try client.initializeDatabase(seedDemoIfEmpty: true)
            refreshAll()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func refreshAll() {
        do {
            templates = try client.listTemplates()
            recentSessions = try client.listSessions(templateId: nil)
            workouts = try client.listWorkouts()
            healthSnapshots = try client.listHealthSnapshots()
            currentTimeline = try client.getDailyTimeline(dateIso: selectedTimelineDateIso)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func createTemplate(_ input: CreateTemplateInput) {
        do {
            _ = try client.createTemplate(input)
            refreshAll()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func logSession(_ input: LogSessionInput) {
        do {
            _ = try client.logSession(input)
            refreshAll()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func importSampleAppleWatchWorkout() {
        do {
            let sample = L4NEHealthKitAdapter.sampleAppleWatchSwimmingWorkout(
                startedAtMs: Int64(Date().timeIntervalSince1970 * 1000)
            )
            _ = try client.importWorkout(sample)
            refreshAll()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func exportJSONBackup() {
        do {
            lastExportPreview = try client.exportBackupJSON()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func exportCSV() {
        do {
            lastExportPreview = try client.exportSessionsCSV()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
