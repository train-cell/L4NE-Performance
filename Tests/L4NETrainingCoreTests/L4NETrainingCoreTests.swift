import XCTest
@testable import L4NETrainingCore
@testable import L4NETrainingUI

final class L4NETrainingCoreTests: XCTestCase {
    private var tempDbPath: String!
    private var client: L4NECoreClient!

    override func setUpWithError() throws {
        let tempDir = FileManager.default.temporaryDirectory
        tempDbPath = tempDir.appendingPathComponent("l4ne_test_\(UUID().uuidString).sqlite").path
        client = L4NECoreClient(databasePath: tempDbPath)
    }

    override func tearDownWithError() throws {
        if let path = tempDbPath {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    func testEngineVersionAndDemoSeedFromSwiftToRust() throws {
        XCTAssertEqual(L4NECoreClient.engineVersion, "0.1.0")
        let initRes = try client.initializeDatabase(seedDemoIfEmpty: true)
        XCTAssertTrue(initRes.seeded)
        XCTAssertEqual(initRes.templatesCount, 3)

        // Second call is idempotent
        let initRes2 = try client.initializeDatabase(seedDemoIfEmpty: true)
        XCTAssertFalse(initRes2.seeded)
    }

    func testAthleticCentisecondNumpadThroughRustFFI() throws {
        let p1 = try client.parseAthleticNumpad(digits: "3240")
        XCTAssertEqual(p1.durationMs, 32_400)
        XCTAssertEqual(p1.formattedDisplay, "32.40")
        XCTAssertEqual(L4NEDurationFormatter.formatMs(p1.durationMs), "32.40s")

        let p2 = try client.parseAthleticNumpad(digits: "10855")
        XCTAssertEqual(p2.durationMs, 68_550)
        XCTAssertEqual(p2.formattedDisplay, "1:08.55")
    }

    func testCreatePyramidAndCompoundTemplatesAndVerifyVersioning() throws {
        _ = try client.initializeDatabase(seedDemoIfEmpty: false)

        // Create a 4 x [2x50m @ 0:50 send-off + 1x100m @ 1:40 send-off] compound template
        let created = try client.createTemplate(
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

        XCTAssertEqual(created.activeVersion.versionNumber, 1)
        XCTAssertEqual(created.activeVersion.totalReps, 12)
        XCTAssertEqual(created.activeVersion.totalDistanceM, 800)
        XCTAssertFalse(created.activeVersion.isHomogeneous)

        let slots = try client.expandTemplateSlots(templateVersionId: created.activeVersion.id)
        XCTAssertEqual(slots.count, 12)
        XCTAssertEqual(slots[0].distanceM, 50)
        XCTAssertEqual(slots[2].distanceM, 100)
        XCTAssertEqual(slots[11].roundIndex, 4)
        XCTAssertEqual(slots[11].distanceM, 100)

        // Log a session on v1
        let repsV1: [RepInput] = slots.map { slot in
            let ms: Int64 = (slot.distanceM == 50) ? 19_000 : 39_500
            return RepInput(slotIndex: slot.slotIndex, durationMs: ms)
        }
        let loggedS1 = try client.logSession(
            LogSessionInput(
                templateId: created.id,
                performedAtMs: 1_795_010_000_000,
                poolLengthM: 50,
                reps: repsV1
            ),
            nowMs: 1_795_010_000_000
        )
        XCTAssertEqual(loggedS1.templateVersionNumber, 1)
        // Verify Send-Off Actual Rest: 50,000ms - 19,000ms = 31,000ms
        XCTAssertEqual(loggedS1.reps[0].actualRestMs, 31_000)

        // Update protocol (change rounds from 4 to 5) -> must mint v2 while preserving s1 on v1
        let updated = try client.updateTemplateProtocol(
            UpdateTemplateProtocolInput(
                templateId: created.id,
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
        XCTAssertEqual(updated.activeVersion.versionNumber, 2)
        XCTAssertEqual(updated.activeVersion.totalReps, 15)

        let historicalSessions = try client.listSessions(templateId: created.id)
        XCTAssertEqual(historicalSessions.first?.templateVersionNumber, 1)
    }

    func testDeterministicAnalyticsTimelineAndExport() throws {
        _ = try client.initializeDatabase(seedDemoIfEmpty: true)
        let templates = try client.listTemplates()
        guard let surfaceTpl = templates.first(where: { $0.name.contains("8×50m") }) else {
            XCTFail("Expected seeded 8x50m Surface template")
            return
        }

        let report = try client.getTemplateAnalytics(templateId: surfaceTpl.id)
        XCTAssertEqual(report.totalSessions, 2)
        XCTAssertEqual(report.personalBestRepDurationMs, 17_950)
        XCTAssertNotNil(report.latestVsPrevious)
        XCTAssertTrue((report.latestVsPrevious?.totalImprovementPct ?? 0) > 5.0)
        XCTAssertEqual(report.healthCorrelations.count, 2)

        let timeline = try client.getDailyTimeline(dateIso: "2026-11-22")
        XCTAssertEqual(timeline.totalVolumeDistanceM, 2400.0)
        XCTAssertEqual(timeline.workouts.count, 1)
        XCTAssertEqual(timeline.standaloneAndLinkedSessions.count, 2)

        let jsonBackup = try client.exportBackupJSON()
        XCTAssertTrue(jsonBackup.contains("8×50m Surface Monofin"))
        let csv = try client.exportSessionsCSV()
        XCTAssertTrue(csv.contains("session_id,date_iso,template_name"))
    }
}
