import Foundation
import SwiftUI
#if canImport(L4NETrainingCore)
import L4NETrainingCore
import L4NETrainingUI
#endif

/// Standalone Swift 6 + Rust FFI Verification Runner (`L4NETestRunner` v1.1.0).
/// Executes deterministic end-to-end assertions across the Swift -> C-ABI -> Rust `libl4ne_core.a` -> SQLite v2 stack.
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
        print("⚡ L4NE Performance — v1.2.0 Full-Stack Swift 6 + Rust FFI Verification Suite")
        let tempDir = FileManager.default.temporaryDirectory
        let dbPath = tempDir.appendingPathComponent("l4ne_verify_v12_\(UUID().uuidString).sqlite").path
        let restoreDbPath = tempDir.appendingPathComponent("l4ne_restore_v12_\(UUID().uuidString).sqlite").path
        defer {
            try? FileManager.default.removeItem(atPath: dbPath)
            try? FileManager.default.removeItem(atPath: restoreDbPath)
        }

        let client = L4NECoreClient(databasePath: dbPath)

        // Gate 1: Engine v1.2.0 & Idempotent Demo Seeding + Schema v3 Diagnostics
        assertEqual(L4NECoreClient.engineVersion, "1.2.0", "Engine version 1.2.0")
        let init1 = try client.initializeDatabase(seedDemoIfEmpty: true)
        assertTrue(init1.seeded, "First init must seed demo protocols")
        assertEqual(init1.templatesCount, 3, "Three demo protocols seeded")
        let init2 = try client.initializeDatabase(seedDemoIfEmpty: true)
        assertTrue(!init2.seeded, "Second init must be idempotent")

        let diag = try client.getDatabaseDiagnostics()
        assertEqual(diag.schemaVersion, 3, "Database schema v3")
        assertEqual(diag.templatesCount, 3)
        assertEqual(diag.sessionsCount, 4)
        print("  ✓ Gate 1: Engine v1.2.0, Schema v3 diagnostics & idempotent initialization passed.")

        // Gate 2: Athletic Centisecond Numpad FFI Parser
        let p1 = try client.parseAthleticNumpad(digits: "3240")
        assertEqual(p1.durationMs, 32_400)
        assertEqual(p1.formattedDisplay, "32.40")
        assertEqual(L4NEDurationFormatter.formatMs(p1.durationMs), "32.40s")

        let p2 = try client.parseAthleticNumpad(digits: "10855")
        assertEqual(p2.durationMs, 68_550)
        assertEqual(p2.formattedDisplay, "1:08.55")
        print("  ✓ Gate 2: Athletic Centisecond Numpad parser ('3240' -> 32.40s, '10855' -> 1:08.55) passed.")

        // Gate 3: v1.1 Live Poolside Companion Timer Deterministic Clock Engine
        let swimTick = try client.computeLiveTimerTick(
            LiveTimerTickInput(
                restMode: .sendOff,
                restOrSendoffMs: 50_000,
                repElapsedMs: 18_200,
                restElapsedMs: nil
            )
        )
        assertEqual(swimTick.phase, "swimming")
        assertEqual(swimTick.remainingRestMs, 31_800)

        let countdownTick = try client.computeLiveTimerTick(
            LiveTimerTickInput(
                restMode: .sendOff,
                restOrSendoffMs: 50_000,
                repElapsedMs: 18_200,
                restElapsedMs: 29_500
            )
        )
        assertEqual(countdownTick.phase, "resting")
        assertEqual(countdownTick.remainingRestMs, 2_300)
        assertEqual(countdownTick.audioCue, "countdown_3_2_1")

        let departTick = try client.computeLiveTimerTick(
            LiveTimerTickInput(
                restMode: .sendOff,
                restOrSendoffMs: 50_000,
                repElapsedMs: 18_200,
                restElapsedMs: 31_800
            )
        )
        assertEqual(departTick.phase, "ready_to_depart")
        assertEqual(departTick.audioCue, "depart_now")
        assertTrue(departTick.shouldAutoAdvance, "Must signal auto-advance on send-off departure")
        print("  ✓ Gate 3: v1.1 Live Poolside Companion timer & Send-Off departure state machine passed.")

        // Gate 4: Compound Rounds, Pyramid Slot Expansion, SWOLF & Template Versioning History
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

        let repsV1: [RepInput] = slots.map { slot in
            let ms: Int64 = (slot.distanceM == 50) ? 19_000 : 39_500
            return RepInput(slotIndex: slot.slotIndex, durationMs: ms, strokeCount: 14)
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
        assertEqual(loggedS1.reps[0].swolfScore, 33, "SWOLF = 19s + 14 strokes = 33")

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
        let versionList = try client.listTemplateVersions(templateId: compoundTpl.id)
        assertEqual(versionList.count, 2, "Must list both v2 and v1 in protocol history")
        let savedSessions = try client.listSessions(templateId: compoundTpl.id)
        assertEqual(savedSessions.first?.templateVersionNumber, 1, "Historical session must remain bound to v1")
        print("  ✓ Gate 4: Compound/Pyramid slot expansion, SWOLF, Send-Off rest & Template Versioning history passed.")

        // Gate 5: Multi-Sport Gym (Tonnage & Epley 1RM) & Field Attempts
        let gymTpl = try client.createTemplate(
            CreateTemplateInput(
                name: "5×5 Back Squat Strength",
                sportCategory: .gym,
                poolLengthM: nil,
                environment: .gym,
                rounds: 1,
                roundRestMs: 0,
                equipment: ["barbell"],
                blocks: [
                    TemplateBlockInput(
                        repeatCount: 5,
                        recordKind: .weightReps,
                        distanceM: nil,
                        strokeOrMovement: "back_squat",
                        restMode: .fixedRest,
                        restOrSendoffMs: 180_000
                    )
                ]
            )
        )
        let gymSession = try client.logSession(
            LogSessionInput(
                templateId: gymTpl.id,
                performedAtMs: 1_795_100_000_000,
                reps: (1...5).map { idx in
                    RepInput(slotIndex: idx, durationMs: nil, rpe: 8, weightKg: 120.0, repsCompleted: 5)
                }
            )
        )
        assertEqual(gymSession.metrics.totalTonnageKg, 3000.0, "5 * 120kg * 5 reps = 3,000kg tonnage")
        assertEqual(gymSession.metrics.bestEstimated1RmKg, 140.0, "Epley 1RM = 120 * (1 + 5/30) = 140.0kg")
        print("  ✓ Gate 5: Multi-sport Gym (Tonnage 3,000kg & Epley 1RM 140.0kg) analytics passed.")

        // Gate 6: v1.1 HealthKit Export Deduplication & JSON Backup Export/Restore Roundtrip
        let exportedSession = try client.markSessionExported(
            sessionId: loggedS1.id,
            externalUuid: "HK-EXPORT-\(loggedS1.id)"
        )
        assertEqual(exportedSession.exportedExternalUuid, "HK-EXPORT-\(loggedS1.id)")
        var duplicateExportRejected = false
        do {
            _ = try client.markSessionExported(sessionId: loggedS1.id, externalUuid: "HK-EXPORT-DUP")
        } catch {
            duplicateExportRejected = true
        }
        assertTrue(duplicateExportRejected, "Duplicate HealthKit export of same session must be rejected")

        let jsonBackup = try client.exportBackupJSON()
        let restoreClient = L4NECoreClient(databasePath: restoreDbPath)
        _ = try restoreClient.initializeDatabase(seedDemoIfEmpty: false)
        let restoreSummary = try restoreClient.importBackupJSON(jsonBackup)
        assertEqual(restoreSummary.templatesRestored, 5)
        assertEqual(restoreSummary.sessionsRestored, 6)
        assertEqual(restoreSummary.workoutsRestored, 1)

        // Second restore into same DB must be 100% idempotent
        let restoreSummary2 = try restoreClient.importBackupJSON(jsonBackup)
        assertEqual(restoreSummary2.templatesRestored, 0)
        assertEqual(restoreSummary2.sessionsRestored, 0)
        print("  ✓ Gate 6: v1.1 HealthKit export deduplication & idempotent JSON Backup Restore roundtrip passed.")

        // Gate 7: v1.2.0 Macrocycle Folder Tags, Intra-Rep Intermediate Splits & Apple Watch Lap Auto-Prefill
        let workouts = try client.listWorkouts()
        let templates = try client.listTemplates()
        guard let pyramidTpl = templates.first(where: { $0.name.contains("Pyramid") }) else {
            fputs("❌ Expected seeded Pyramid template\n", stderr)
            exit(1)
        }
        assertEqual(pyramidTpl.folderTag, "Lactate Tolerance")
        let prefilledPyramid = try client.prefillRepsFromWorkoutLaps(
            workoutId: workouts[0].id,
            templateVersionId: pyramidTpl.activeVersion.id
        )
        assertEqual(prefilledPyramid.count, 4)
        assertEqual(prefilledPyramid[0].durationMs, 18_200)
        assertEqual(prefilledPyramid[1].durationMs, 18_350 + 18_400)
        assertEqual(prefilledPyramid[1].splitsMs, [18_350, 18_400])
        assertEqual(prefilledPyramid[2].durationMs, 18_300 + 18_250 + 18_300)
        print("  ✓ Gate 7: v1.2.0 Macrocycle folder tags, intra-rep splits & Apple Watch lap auto-prefill passed.")
        print("✅ ALL 7 v1.2.0 FULL-STACK VERIFICATION GATES PASSED (100%).")
    }
}
