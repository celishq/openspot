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
        XCTAssertEqual(scan.commands.map(\.name), ["Apps", "Caffeinate", "Files", "Downloads", "Screenshots", "Paste Screenshot"])
        XCTAssertEqual(scan.commands.map(\.key?.name), ["a", "c", "f", "d", "s", "v"])
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

    func testCaffeinateReportsIfItIsOnAndOffersItsDurations() async throws {
        let caffeinate = try XCTUnwrap(try scan.commands.first { $0.name == "Caffeinate" })

        let state = try await caffeinate.state(timeout: 5)
        let lines = try await caffeinate.items(timeout: 5)

        XCTAssertEqual(state.title, "Caffeinate")
        XCTAssertNotNil(state.on)
        XCTAssertEqual(lines.items.prefix(4).map(\.run), ["1800", "3600", "7200", "0"])
        XCTAssertEqual(lines.errors, [])
        XCTAssertEqual(caffeinate.pick, .stay)
    }

    func testAppsListsEachAppWithItsPathAndNoBadLine() async throws {
        let apps = try XCTUnwrap(try scan.commands.first { $0.name == "Apps" })

        let lines = try await apps.items(timeout: 10)
        let finder = try XCTUnwrap(lines.items.first { $0.title == "Finder" })

        XCTAssertEqual(lines.errors, [])
        XCTAssertEqual(finder.run, "/System/Library/CoreServices/Finder.app")
        XCTAssertEqual(finder.file, finder.run)
        XCTAssertTrue(apps.isGlobal)
        XCTAssertGreaterThan(lines.items.filter { $0.run.hasPrefix("/System/Applications/") }.count, 5)
    }

    func testFilesIsLiveAndGivesNothingForATooShortSearch() async throws {
        let files = try XCTUnwrap(try scan.commands.first { $0.name == "Files" })

        let lines = try await files.items(query: "a", timeout: 5)

        XCTAssertEqual(files.search, .live)
        XCTAssertEqual(lines.items, [])
    }
}
