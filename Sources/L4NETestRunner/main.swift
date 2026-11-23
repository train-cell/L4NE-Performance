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
        print("⚡ L4NE Performance — v1.3.0 Full-Stack Swift 6 + Rust FFI Verification Suite")
        let tempDir = FileManager.default.temporaryDirectory
        let dbPath = tempDir.appendingPathComponent("l4ne_verify_v13_\(UUID().uuidString).sqlite").path
        let restoreDbPath = tempDir.appendingPathComponent("l4ne_restore_v13_\(UUID().uuidString).sqlite").path
        defer {
            try? FileManager.default.removeItem(atPath: dbPath)
            try? FileManager.default.removeItem(atPath: restoreDbPath)
        }

        let client = L4NECoreClient(databasePath: dbPath)

        // Gate 1: Engine v1.3.0 & Idempotent Demo Seeding (5 Templates: Examples A, B, C, Pyramid, Compound) + Schema v4 Diagnostics
        assertEqual(L4NECoreClient.engineVersion, "1.3.0", "Engine version 1.3.0")
        let init1 = try client.initializeDatabase(seedDemoIfEmpty: true)
        assertTrue(init1.seeded, "First init must seed demo protocols")
        assertEqual(init1.templatesCount, 5, "Five demo protocols seeded (Overview Examples A, B, C + Pyramid + Compound)")
        let init2 = try client.initializeDatabase(seedDemoIfEmpty: true)
        assertTrue(!init2.seeded, "Second init must be idempotent")

        let diag = try client.getDatabaseDiagnostics()
        assertEqual(diag.schemaVersion, 4, "Database schema v4")
        assertEqual(diag.templatesCount, 5)
        assertEqual(diag.sessionsCount, 4)
        print("  ✓ Gate 1: Engine v1.3.0, Schema v4 diagnostics & 5 seeded protocols (Examples A/B/C, Pyramid, Compound) passed.")

        // Gate 2: Athletic Centisecond Numpad FFI Parser (Left-to-Right: Seconds -> Centiseconds)
        let pOne = try client.parseAthleticNumpad(digits: "3")
        assertEqual(pOne.durationMs, 3_000)
        assertEqual(pOne.formattedDisplay, "3.00")

        let pTwo = try client.parseAthleticNumpad(digits: "32")
        assertEqual(pTwo.durationMs, 32_000)
        assertEqual(pTwo.formattedDisplay, "32.00")

        let pThree = try client.parseAthleticNumpad(digits: "324")
        assertEqual(pThree.durationMs, 32_400)
        assertEqual(pThree.formattedDisplay, "32.40")

        let p1 = try client.parseAthleticNumpad(digits: "3240")
        assertEqual(p1.durationMs, 32_400)
        assertEqual(p1.formattedDisplay, "32.40")
        assertEqual(L4NEDurationFormatter.formatMs(p1.durationMs), "32.40s")

        let p2 = try client.parseAthleticNumpad(digits: "10855")
        assertEqual(p2.durationMs, 68_550)
        assertEqual(p2.formattedDisplay, "1:08.55")
        print("  ✓ Gate 2: Left-to-Right Athletic Centisecond Numpad parser ('3' -> 3.00s, '32' -> 32.00s, '324' -> 32.40s, '3240' -> 32.40s) passed.")

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
        assertEqual(restoreSummary.templatesRestored, 7)
        assertEqual(restoreSummary.sessionsRestored, 6)
        assertEqual(restoreSummary.workoutsRestored, 1)

        // Second restore into same DB must be 100% idempotent
        let restoreSummary2 = try restoreClient.importBackupJSON(jsonBackup)
        assertEqual(restoreSummary2.templatesRestored, 0)
        assertEqual(restoreSummary2.sessionsRestored, 0)
        print("  ✓ Gate 6: v1.1 HealthKit export deduplication & idempotent JSON Backup Restore roundtrip passed.")

        // Gate 7: v1.2.0 Macrocycle Folder Tags, Intra-Rep Intermediate Splits & Apple Watch Lap Auto-Prefill
        let workouts = try client.listWorkouts()
        assertEqual(workouts[0].associatedTemplatesCount, 2, "Workout has 2 associated templates")
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

        // Gate 8: v1.3.0 Multi-Theme Engine (Bevel Graphite / Strava Obsidian / Bevel Navy / Lane 4 Carbon / Daylight),
        // Overview Examples B vs C Distinct Protocol Verification, Health Context Baselines & Standalone Workout Flow
        guard let exB = templates.first(where: { $0.name.contains("6×100m Freestyle — 60s") }),
              let exC = templates.first(where: { $0.name.contains("6×100m Freestyle — 30s") }) else {
            fputs("❌ Expected seeded Overview Examples B & C (6x100m @ 60s vs 30s)\n", stderr)
            exit(1)
        }
        assertTrue(exB.activeVersion.protocolHash != exC.activeVersion.protocolHash, "6x100m @ 60s rest and 6x100m @ 30s rest must have distinct SHA-256 protocol hashes")

        let initialSettings = try client.getAppSettings()
        assertEqual(initialSettings.activeTheme, .graphiteBevel)
        for preset in ThemePreset.allCases {
            var s = initialSettings
            s.activeTheme = preset
            let saved = try client.updateAppSettings(s)
            assertEqual(saved.activeTheme, preset)
            let pal = L4NEPalette.forPreset(preset)
            assertEqual(pal.preset, preset)
        }

        let healthSummary = try client.getHealthContextSummary()
        assertEqual(healthSummary.snapshotsCount, 2)
        assertTrue((healthSummary.baselineHrvSdnnMs ?? 0) > 60.0, "Personal HRV baseline > 60ms")
        assertTrue((healthSummary.bevelRecoveryRingPct ?? 0) > 80.0, "Bevel recovery ring > 80%")
        assertTrue((healthSummary.bevelSleepRingPct ?? 0) > 95.0, "Bevel sleep ring > 95%")

        let standaloneWorkout = try client.setWorkoutStandalone(workoutId: workouts[0].id, keptAsStandalone: true)
        assertEqual(standaloneWorkout.keptAsStandalone, true)

        // Verify Sport-Specific Equipment Catalog & Template Deletion (even with logged sessions)
        let finswimEqIds = Set(SportCategory.finswimming.availableEquipment.map(\.id))
        assertTrue(finswimEqIds.contains("oxygen_tank"), "Finswimming equipment must include oxygen_tank (Φιάλη Οξυγόνου)")
        assertTrue(finswimEqIds.contains("mask"), "Finswimming equipment must include mask (Μάσκα)")
        assertTrue(finswimEqIds.contains("snorkel"), "Finswimming equipment must include snorkel (Αναπνευστήρας)")
        assertTrue(finswimEqIds.contains("monofin"), "Finswimming equipment must include monofin (Μονοπέδιλο)")

        let beforeDeleteCount = try client.listTemplates(includeArchived: true).count
        let wasDeleted = try client.deleteTemplate(templateId: compoundTpl.id)
        assertTrue(wasDeleted, "deleteTemplate must delete template and its sessions")
        let afterDeleteCount = try client.listTemplates(includeArchived: true).count
        assertEqual(afterDeleteCount, beforeDeleteCount - 1, "Template count must decrease by 1 after deletion")

        print("  ✓ Gate 8: v1.3.0 Multi-Theme Engine, Sport Equipment Catalog, Template Deletion & Health Context Baselines passed.")

        // Gate 9: Segmented PCr Race Prediction & Recalculator Model (ΤΗΕ ΘΕΩΡΙ.txt v2.0 Case Studies A & B + Automatic Template Predictions)
        let pcrCaseA = try client.calculatePcrPrediction(
            PcrRecalculatorInput(
                targetDistanceM: 400,
                label: "Case Study A — 400m Segmented",
                tauSeconds: 28.0,
                customK: 0.13,
                customFf: 0.015,
                segments: [
                    PcrSegmentInput(distanceM: 200, durationMs: 82_000, restBeforeMs: 0),
                    PcrSegmentInput(distanceM: 150, durationMs: 63_900, restBeforeMs: 20_000)
                ]
            )
        )
        assertEqual(pcrCaseA.modelMode, "segmented_pcr")
        assertEqual(pcrCaseA.segments[0].penaltyDeltaPct, 0.0, "Segment 1 (>150m) must receive 0% penalty")
        assertEqual(pcrCaseA.segments[1].penaltyDeltaPct, 8.13, "Segment 2 penalty must be 8.13%")
        assertEqual(pcrCaseA.predictedRaceTimeMs, 173_590, "Predicted 400m time must equal 173.59s")
        assertEqual(pcrCaseA.formattedPredictedTime, "2:53.59", "Formatted 400m prediction must equal 2:53.59")

        let pcrCaseB = try client.calculatePcrPrediction(
            PcrRecalculatorInput(
                targetDistanceM: 200,
                label: "Case Study B — 4x50m Symmetric",
                tauSeconds: 28.0,
                customK: 0.16,
                customFf: 0.0,
                segments: [
                    PcrSegmentInput(distanceM: 50, durationMs: 17_000, restBeforeMs: 0),
                    PcrSegmentInput(distanceM: 50, durationMs: 18_000, restBeforeMs: 15_000),
                    PcrSegmentInput(distanceM: 50, durationMs: 18_700, restBeforeMs: 15_000),
                    PcrSegmentInput(distanceM: 50, durationMs: 18_500, restBeforeMs: 15_000)
                ]
            )
        )
        assertEqual(pcrCaseB.modelMode, "symmetric_broken")
        assertEqual(pcrCaseB.penaltyDeltaPct, 6.64, "4x50m @ 15s stop penalty must be 6.64%")
        assertEqual(pcrCaseB.predictedRaceTimeMs, 76_990, "Predicted 200m time must equal 76.99s")

        if let monofin8x50 = templates.first(where: { $0.name.contains("8×50m") }) {
            let tplPreds = try client.getTemplatePcrPredictions(templateId: monofin8x50.id)
            assertEqual(tplPreds.count, 2, "8x50m template must automatically produce both 200m (4x50m) and 400m (8x50m) PCr predictions")
            assertEqual(tplPreds[0].targetDistanceM, 200)
            assertEqual(tplPreds[1].targetDistanceM, 400)
        }
        assertEqual(L4NEVisualMode.allCases.count, 2, "Must support both Minimal and Maximized visual modes")
        assertEqual(L4NEVisualMode.maximized.badgeTitle, "🎬 MAXIMIZED")
        assertEqual(L4NEVisualMode.minimal.badgeTitle, "◐ MINIMAL")
        print("  ✓ Gate 9: Segmented PCr Race Prediction & Recalculator (Case Study A -> 2:53.59, Case Study B -> 76.99s, 8x50m -> 200m & 400m) + Minimal/Maximized Motion Engine passed.")

        // Gate 10: Personal Records & Historical Progression Over Time Tab (Seeded 50m/200m/400m progressions + Create/Delete Personal Record)
        let progressions = try client.listRecordProgressions()
        assertEqual(progressions.count, 3, "Three seeded personal record event progressions (50m, 200m, 400m Surface)")
        if let p50 = progressions.first(where: { $0.eventName == "50m Επιφάνεια" }) {
            assertEqual(p50.entriesCount, 3)
            assertEqual(p50.initialRecord.durationMs, 19_100)
            assertEqual(p50.personalBest.durationMs, 17_950)
            assertEqual(p50.totalDeltaMs, -1_150)
            assertTrue(p50.totalImprovementPct > 6.0, "50m progression improvement > 6.0%")
        }
        let newRec = try client.createPersonalRecord(
            CreatePersonalRecordInput(
                sportCategory: .finswimming,
                eventName: "50m Επιφάνεια",
                recordKind: .timedDistance,
                poolLengthM: 50,
                distanceM: 50,
                durationMs: 17_600,
                equipment: ["monofin", "snorkel", "mask"],
                competitionOrLocation: "Πανευρωπαϊκό Πρωτάθλημα · Νέο PB",
                achievedAtMs: 1_796_000_000_000
            )
        )
        assertEqual(newRec.formattedValue, "17.60s")
        let updatedProg = try client.listRecordProgressions()
        if let p50Updated = updatedProg.first(where: { $0.eventName == "50m Επιφάνεια" }) {
            assertEqual(p50Updated.entriesCount, 4)
            assertEqual(p50Updated.personalBest.durationMs, 17_600, "New 17.60s entry must become the Personal Best")
        }
        let recDeleted = try client.deletePersonalRecord(recordId: newRec.id)
        assertTrue(recDeleted, "deletePersonalRecord must succeed")
        print("  ✓ Gate 10: Personal Records & Historical Progression Over Time ('50m/200m/400m Επιφάνεια' curves, PB tracking & delta %) passed.")
        print("✅ ALL 10 v1.4.0 FULL-STACK VERIFICATION GATES PASSED (100%).")
    }
}
