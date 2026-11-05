import XCTest
@testable import OpenspotCore

final class SamplePluginsTests: XCTestCase {
    private var scan: ScanResult {
        get throws {
            let root = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            return try PluginFolder(url: root.appendingPathComponent("plugins")).scan()
        }
    }

    func testTheFolderHoldsEveryCommandAndRefusesNone() throws {
        let scan = try scan

        XCTAssertEqual(scan.refused, [])
        XCTAssertEqual(scan.commands.map(\.name), ["Safari", "Caffeinate", "Downloads", "Screenshots", "Paste Screenshot"])
        XCTAssertEqual(scan.commands.map(\.key?.name), ["b", "c", "d", "s", "v"])
    }

    func testOnePluginHoldsSeveralCommands() throws {
        let folders = try XCTUnwrap(try scan.plugins.first { $0.name == "Folders" })

        XCTAssertEqual(folders.commands.map(\.name), ["Downloads", "Screenshots"])
    }

    func testEveryCommandCanBeRun() throws {
        for command in try scan.commands {
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: command.url.path), command.name)
        }
    }

    func testCaffeinateOffersItsDurationsAndReportsIfItIsOn() async throws {
        let caffeinate = try XCTUnwrap(try scan.commands.first { $0.name == "Caffeinate" })

        let state = try await caffeinate.state(timeout: 5)

        XCTAssertEqual(state.title, "Caffeinate")
        XCTAssertEqual(state.items?.prefix(4).map(\.run), ["1800", "3600", "7200", "0"])
        XCTAssertNotNil(state.on)
    }
}
