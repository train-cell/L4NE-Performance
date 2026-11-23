import XCTest
@testable import L4NETrainingCore
@testable import L4NETrainingUI

final class L4NETrainingCoreTests: XCTestCase {
    private var tempDbPath: String!
    private var client: L4NECoreClient!

    override func setUpWithError() throws {
        let tempDir = FileManager.default.temporaryDirectory
        tempDbPath = tempDir.appendingPathComponent("l4ne_test_v11_\(UUID().uuidString).sqlite").path
        client = L4NECoreClient(databasePath: tempDbPath)
    }

    override func tearDownWithError() throws {
        if let path = tempDbPath {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    func testEngineVersionV11AndDiagnostics() throws {
        XCTAssertEqual(L4NECoreClient.engineVersion, "1.3.0")
        let initRes = try client.initializeDatabase(seedDemoIfEmpty: true)
        XCTAssertTrue(initRes.seeded)
        XCTAssertEqual(initRes.templatesCount, 5)

        let diag = try client.getDatabaseDiagnostics()
        XCTAssertEqual(diag.schemaVersion, 4)
        XCTAssertEqual(diag.templatesCount, 5)
        XCTAssertEqual(diag.sessionsCount, 4)
    }

    func testLivePoolsideCompanionTimerStateMachineV11() throws {
        let tick = try client.computeLiveTimerTick(
            LiveTimerTickInput(
                restMode: .sendOff,
                restOrSendoffMs: 50_000,
                repElapsedMs: 18_200,
                restElapsedMs: 29_500
            )
        )
        XCTAssertEqual(tick.phase, "resting")
        XCTAssertEqual(tick.remainingRestMs, 2_300)
        XCTAssertEqual(tick.audioCue, "countdown_3_2_1")
    }

    func testMultiSportGymAndBackupRestoreRoundtripV11() throws {
        _ = try client.initializeDatabase(seedDemoIfEmpty: true)
        let backupJson = try client.exportBackupJSON()

        let restorePath = FileManager.default.temporaryDirectory
            .appendingPathComponent("l4ne_restore_xctest_\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: restorePath) }

        let restoreClient = L4NECoreClient(databasePath: restorePath)
        _ = try restoreClient.initializeDatabase(seedDemoIfEmpty: false)
        let res = try restoreClient.importBackupJSON(backupJson)
        XCTAssertEqual(res.templatesRestored, 5)
        XCTAssertEqual(res.sessionsRestored, 4)
    }
}
