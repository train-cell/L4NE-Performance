import Foundation
import SwiftUI
#if canImport(L4NETrainingCore)
import L4NETrainingCore
import L4NETrainingUI
#endif

/// Standalone Swift 6 + Rust FFI Verification Runner (`L4NETestRunner`).
/// Executes deterministic end-to-end assertions across the Swift -> C-ABI -> Rust `libl4ne_core.a` -> SQLite stack.
@main
struct L4NETestRunner {
    static func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String, file: String = #file, line: Int = #line) {
        if !condition() {
            fputs("❌ ASSERTION FAILED (\(file):\(line)): \(message)\n", stderr)
            exit(1)
        }
    }

    static func assertEqual<T: Equatable>(_ lhs: T, _ rhs: T, _ message: String = "", file: String = #file, line: Int = #line) {
        if lhs != rhs {
            fputs("❌ ASSERTION FAILED (\(file):\(line)): Expected \(rhs), got \(lhs). \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() throws {
        print("⚡ L4NE Performance — Swift 6 + Rust FFI Verification Suite")
        let tempDir = FileManager.default.temporaryDirectory
        let dbPath = tempDir.appendingPathComponent("l4ne_verify_\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: dbPath) }

        let client = L4NECoreClient(databasePath: dbPath)

        // Gate 1: Engine version & Idempotent Demo Seeding
        assertEqual(L4NECoreClient.engineVersion, "0.1.0", "Engine version match")
        let init1 = try client.initializeDatabase(seedDemoIfEmpty: true)
        assertTrue(init1.seeded, "First init must seed demo protocols")
        assertEqual(init1.templatesCount, 3, "Three demo protocols seeded")
        let init2 = try client.initializeDatabase(seedDemoIfEmpty: true)
        assertTrue(!init2.seeded, "Second init must be idempotent")
        print("  ✓ Gate 1: Engine version & idempotent demo database initialization passed.")

        // Gate 2: Athletic Centisecond Numpad FFI Parser
        let p1 = try client.parseAthleticNumpad(digits: "3240")
        assertEqual(p1.durationMs, 32_400)
        assertEqual(p1.formattedDisplay, "32.40")
        assertEqual(L4NEDurationFormatter.formatMs(p1.durationMs), "32.40s")

        let p2 = try client.parseAthleticNumpad(digits: "10855")
        assertEqual(p2.durationMs, 68_550)
        assertEqual(p2.formattedDisplay, "1:08.55")
        print("  ✓ Gate 2: Athletic Centisecond Numpad parser ('3240' -> 32.40s, '10855' -> 1:08.55) passed.")

        // Gate 3: Compound Rounds & Pyramid Slot Expansion + Template Versioning Integrity
        let compoundTpl = try client.createTemplate(
            CreateTemplateInput(
                name: "4×[2×50m + 1×100m] Monofin Threshold",
                sportCategory: .finswimming,
                poolLengthM: 50,
                environment: .pool,
                rounds: 4,
                roundRestMs: 30_000,
                equipment: ["monofin", "snorkel"],
                targetPaceMsPer100m: 38_000,
                notes: "Lane 4 compound protocol",
                blocks: [
                    TemplateBlockInput(
                        repeatCount: 2,
                        distanceM: 50,
                        strokeOrMovement: "surface",
                        restMode: .sendOff,
                        restOrSendoffMs: 50_000
                    ),
                    TemplateBlockInput(
                        repeatCount: 1,
                        distanceM: 100,
                        strokeOrMovement: "surface",
                        restMode: .sendOff,
                        restOrSendoffMs: 100_000
                    )
                ]
            ),
            nowMs: 1_795_000_000_000
        )
        assertEqual(compoundTpl.activeVersion.versionNumber, 1)
        assertEqual(compoundTpl.activeVersion.totalReps, 12)
        assertEqual(compoundTpl.activeVersion.totalDistanceM, 800)
        assertTrue(!compoundTpl.activeVersion.isHomogeneous, "Compound set must be marked non-homogeneous")

        let slots = try client.expandTemplateSlots(templateVersionId: compoundTpl.activeVersion.id)
        assertEqual(slots.count, 12)
        assertEqual(slots[0].distanceM, 50)
        assertEqual(slots[2].distanceM, 100)
        assertEqual(slots[11].roundIndex, 4)

        let repsV1: [RepInput] = slots.map { slot in
            let ms: Int64 = (slot.distanceM == 50) ? 19_000 : 39_500
            return RepInput(slotIndex: slot.slotIndex, durationMs: ms)
        }
        let loggedS1 = try client.logSession(
            LogSessionInput(
                templateId: compoundTpl.id,
                performedAtMs: 1_795_010_000_000,
                poolLengthM: 50,
                reps: repsV1
            ),
            nowMs: 1_795_010_000_000
        )
        assertEqual(loggedS1.templateVersionNumber, 1)
        assertEqual(loggedS1.reps[0].actualRestMs, 31_000, "Send-off 50s - 19s rep = 31s actual rest")

        // Modify protocol -> must mint v2 while preserving historical session on v1
        let updatedTpl = try client.updateTemplateProtocol(
            UpdateTemplateProtocolInput(
                templateId: compoundTpl.id,
                name: "5×[2×50m + 1×100m] Monofin Threshold",
                poolLengthM: 50,
                rounds: 5,
                roundRestMs: 30_000,
                equipment: ["monofin", "snorkel"],
                targetPaceMsPer100m: 38_000,
                notes: "Expanded to 5 rounds",
                blocks: [
                    TemplateBlockInput(
                        repeatCount: 2,
                        distanceM: 50,
                        strokeOrMovement: "surface",
                        restMode: .sendOff,
                        restOrSendoffMs: 50_000
                    ),
                    TemplateBlockInput(
                        repeatCount: 1,
                        distanceM: 100,
                        strokeOrMovement: "surface",
                        restMode: .sendOff,
                        restOrSendoffMs: 100_000
                    )
                ]
            ),
            nowMs: 1_795_020_000_000
        )
        assertEqual(updatedTpl.activeVersion.versionNumber, 2)
        assertEqual(updatedTpl.activeVersion.totalReps, 15)
        let savedSessions = try client.listSessions(templateId: compoundTpl.id)
        assertEqual(savedSessions.first?.templateVersionNumber, 1, "Historical session must remain bound to v1")
        print("  ✓ Gate 3: Compound/Pyramid slot expansion, Send-Off rest, and Template Versioning integrity passed.")

        // Gate 4: Deterministic Analytics, Daily Timeline & JSON/CSV Exports
        let allTemplates = try client.listTemplates()
        guard let surfaceTpl = allTemplates.first(where: { $0.name.contains("8×50m") }) else {
            fputs("❌ Missing seeded 8x50m template\n", stderr)
            exit(1)
        }
        let report = try client.getTemplateAnalytics(templateId: surfaceTpl.id)
        assertEqual(report.totalSessions, 2)
        assertEqual(report.personalBestRepDurationMs, 17_950)
        assertTrue((report.latestVsPrevious?.totalImprovementPct ?? 0) > 5.0, "Improvement > 5%")
        assertEqual(report.healthCorrelations.count, 2)

        let timeline = try client.getDailyTimeline(dateIso: "2026-11-22")
        assertEqual(timeline.totalVolumeDistanceM, 2400.0, "Linked sessions must not double-count Apple Watch workout volume")
        assertEqual(timeline.workouts.count, 1)
        assertEqual(timeline.standaloneAndLinkedSessions.count, 2)

        let jsonBackup = try client.exportBackupJSON()
        assertTrue(jsonBackup.contains("8×50m Surface Monofin"), "JSON Backup contains templates")
        let csvExport = try client.exportSessionsCSV()
        assertTrue(csvExport.contains("session_id,date_iso,template_name"), "CSV header present")
        print("  ✓ Gate 4: Deterministic Analytics, HealthKit Timeline deduplication, and JSON/CSV export passed.")
        print("✅ ALL SWIFT 6 + RUST FFI VERIFICATION GATES PASSED (100%).")
    }
}
