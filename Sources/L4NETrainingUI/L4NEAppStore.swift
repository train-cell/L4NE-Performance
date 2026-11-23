import Foundation
import SwiftUI
#if canImport(L4NETrainingCore)
import L4NETrainingCore
#endif

/// Main Observable ViewModel (v1.3) coordinating local SQLite state, Multi-Theme presets,
/// Bevel rings, and Strava activity feeds through `L4NECoreClient`.
@MainActor
public final class L4NEAppStore: ObservableObject {
    public let client: L4NECoreClient
    public let healthKitAdapter = L4NEHealthKitAdapter()

    @Published public var appSettings: AppSettings = AppSettings()
    @Published public var activePalette: L4NEPalette = .forPreset(.graphiteBevel)
    @Published public var visualMode: L4NEVisualMode = .maximized
    @Published public var maximizeConfig: L4NEMaximizeConfig = .balancedPreset
    @Published public var soundEnabled: Bool = true
    @Published public var templates: [TemplateWithVersion] = []

    public var isMaximized: Bool {
        maximizeConfig.isEffectivelyMaximized
    }

    public func toggleVisualMode() {
        if maximizeConfig.isEffectivelyMaximized {
            applyMaximizeConfig(.minimalPreset)
        } else {
            applyMaximizeConfig(.balancedPreset)
        }
    }

    public func setVisualMode(_ mode: L4NEVisualMode) {
        applyMaximizeConfig(mode == .maximized ? .balancedPreset : .minimalPreset)
    }

    public func applyMaximizeConfig(_ config: L4NEMaximizeConfig) {
        maximizeConfig = config
        visualMode = config.isEffectivelyMaximized ? .maximized : .minimal
        soundEnabled = config.soundAndHapticsEnabled
        L4NESoundHapticsEngine.shared.soundEnabled = config.soundAndHapticsEnabled
        L4NESoundHapticsEngine.shared.hapticsEnabled = config.soundAndHapticsEnabled
        if config.soundAndHapticsEnabled {
            L4NESoundHapticsEngine.shared.trigger(.waveSweep)
        }
    }

    public func toggleSound() {
        soundEnabled.toggle()
        maximizeConfig.soundAndHapticsEnabled = soundEnabled
        L4NESoundHapticsEngine.shared.soundEnabled = soundEnabled
        if soundEnabled {
            L4NESoundHapticsEngine.shared.trigger(.dropletTap)
        }
    }
    @Published public var includeArchivedTemplates: Bool = false
    @Published public var selectedSportFilter: SportCategory? = nil
    @Published public var recentSessions: [SessionWithReps] = []
    @Published public var workouts: [Workout] = []
    @Published public var healthSnapshots: [DailyHealthSnapshot] = []
    @Published public var healthContext: HealthContextSummary?
    @Published public var selectedTimelineDateIso: String = "2026-11-22"
    @Published public var currentTimeline: DailyTrainingTimeline?
    @Published public var diagnostics: DatabaseDiagnostics?
    @Published public var healthKitStatus: L4NEHealthKitStatus = .availableNotRequested
    @Published public var lastErrorMessage: String?
    @Published public var lastStatusBanner: String?
    @Published public var lastExportPreview: String?

    public init(databasePath: String? = nil) {
        let resolvedPath: String
        if let databasePath {
            resolvedPath = databasePath
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            resolvedPath = docs.appendingPathComponent("l4ne_performance_v1_4.sqlite").path
        }
        self.client = L4NECoreClient(databasePath: resolvedPath)
        self.bootstrap()
    }

    public var filteredTemplates: [TemplateWithVersion] {
        guard let filter = selectedSportFilter else { return templates }
        return templates.filter { $0.sportCategory == filter }
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
            if let loadedSettings = try? client.getAppSettings() {
                appSettings = loadedSettings
                let pal = L4NEPalette.forPreset(loadedSettings.activeTheme)
                L4NETheme.activePalette = pal
                activePalette = pal
            }
            templates = try client.listTemplates(includeArchived: includeArchivedTemplates)
            recentSessions = try client.listSessions(templateId: nil)
            workouts = try client.listWorkouts()
            healthSnapshots = try client.listHealthSnapshots()
            healthContext = try? client.getHealthContextSummary()
            currentTimeline = try client.getDailyTimeline(dateIso: selectedTimelineDateIso)
            diagnostics = try client.getDatabaseDiagnostics()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func selectTheme(_ preset: ThemePreset) {
        var updated = appSettings
        updated.activeTheme = preset
        updated.updatedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
        do {
            let saved = try client.updateAppSettings(updated)
            appSettings = saved
            let pal = L4NEPalette.forPreset(saved.activeTheme)
            L4NETheme.activePalette = pal
            activePalette = pal
            L4NESoundHapticsEngine.shared.trigger(.waveSweep)
            lastStatusBanner = "Ενεργοποιήθηκε το theme '\(preset.displayTitle)'."
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func createTemplate(_ input: CreateTemplateInput) {
        do {
            let created = try client.createTemplate(input)
            L4NESoundHapticsEngine.shared.trigger(.victoryFanfare)
            lastStatusBanner = "Δημιουργήθηκε το template '\(created.name)' (v\(created.activeVersion.versionNumber))."
            refreshAll()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func updateTemplateProtocol(_ input: UpdateTemplateProtocolInput) {
        do {
            let updated = try client.updateTemplateProtocol(input)
            L4NESoundHapticsEngine.shared.trigger(.victoryFanfare)
            lastStatusBanner = "Ενημερώθηκε το '\(updated.name)' → ενεργή έκδοση v\(updated.activeVersion.versionNumber)."
            refreshAll()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func toggleTemplateArchived(_ template: TemplateWithVersion) {
        do {
            let updated = try client.setTemplateArchived(
                templateId: template.id,
                isArchived: !template.isArchived
            )
            L4NESoundHapticsEngine.shared.trigger(.dropletTap)
            lastStatusBanner = updated.isArchived
                ? "Αρχειοθετήθηκε το '\(updated.name)'."
                : "Επαναφέρθηκε το '\(updated.name)'."
            refreshAll()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func deleteTemplate(templateId: String) {
        do {
            _ = try client.deleteTemplate(templateId: templateId)
            L4NESoundHapticsEngine.shared.trigger(.deleteThud)
            lastStatusBanner = "Το template διαγράφηκε."
            refreshAll()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func logSession(_ input: LogSessionInput) {
        do {
            let logged = try client.logSession(input)
            L4NESoundHapticsEngine.shared.trigger(.victoryFanfare)
            lastStatusBanner = "Καταγράφηκε session για '\(logged.templateName)' (\(logged.reps.count) reps)."
            refreshAll()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func deleteSession(sessionId: String) {
        do {
            _ = try client.deleteSession(sessionId: sessionId)
            L4NESoundHapticsEngine.shared.trigger(.deleteThud)
            lastStatusBanner = "Το session διαγράφηκε."
            refreshAll()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func linkSessionToWorkout(sessionId: String, workoutId: String?) {
        do {
            _ = try client.linkSessionToWorkout(sessionId: sessionId, workoutId: workoutId)
            lastStatusBanner = workoutId != nil
                ? "Το session συνδέθηκε με το Workout."
                : "Αφαιρέθηκε η σύνδεση με το Workout."
            refreshAll()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func toggleWorkoutStandalone(_ workout: Workout) {
        do {
            let nextState = !(workout.keptAsStandalone ?? false)
            _ = try client.setWorkoutStandalone(workoutId: workout.id, keptAsStandalone: nextState)
            lastStatusBanner = nextState
                ? "Το Workout κρατήθηκε ως γενική καταγραφή (Standalone)."
                : "Το Workout είναι διαθέσιμο για αντιστοίχιση με Templates."
            refreshAll()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func exportSessionToAppleHealth(session: SessionWithReps, sport: SportCategory) async {
        do {
            let updated = try await healthKitAdapter.exportSessionToHealthKit(
                session: session,
                sportCategory: sport,
                client: client
            )
            lastStatusBanner = "Εξήχθη στο Apple HealthKit (\(updated.exportedExternalUuid ?? "HKWorkout"))."
            refreshAll()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func saveHealthSnapshot(_ snapshot: DailyHealthSnapshot) {
        do {
            _ = try client.upsertHealthSnapshot(snapshot)
            lastStatusBanner = "Αποθηκεύτηκε το Health Snapshot (\(snapshot.dateIso))."
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
            lastStatusBanner = "Εισήχθη προπόνηση Apple Watch Ultra 2 (2.800m · 50m Pool)."
            refreshAll()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func exportJSONBackup() {
        do {
            let json = try client.exportBackupJSON()
            lastExportPreview = json
            lastStatusBanner = "Εξήχθη πλήρες JSON Backup (\(json.count) bytes)."
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func restoreJSONBackup(_ jsonString: String) {
        do {
            let res = try client.importBackupJSON(jsonString)
            lastStatusBanner = "Restore ολοκληρώθηκε: +\(res.templatesRestored) templates, +\(res.sessionsRestored) sessions, +\(res.workoutsRestored) workouts."
            refreshAll()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    public func exportCSV() {
        do {
            let csv = try client.exportSessionsCSV()
            lastExportPreview = csv
            lastStatusBanner = "Εξήχθη αρχείο CSV όλων των επαναλήψεων."
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
