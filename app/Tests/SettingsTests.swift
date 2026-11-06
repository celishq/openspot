import XCTest
@testable import OpenspotCore

@MainActor
final class SettingsTests: XCTestCase {
    private var folder: URL!

    private var file: ConfigFile {
        ConfigFile(url: folder.appendingPathComponent("config.toml"))
    }

    private var spot: PluginCommand {
        get throws {
            let commands = ShippedSpot.commands(folder: folder, guide: folder, app: "", config: file)
            return try XCTUnwrap(commands.first { $0.name == "Settings" })
        }
    }

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-settings-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testTwoSpotsShipAndSettingsHasNoLetter() throws {
        let commands = ShippedSpot.commands(folder: folder, guide: folder, app: "", config: file)

        XCTAssertEqual(commands.map(\.name), ["Plugins", "Settings"])
        XCTAssertEqual(commands.map(\.key?.name), ["p", nil])
    }

    func testTheSheetShowsTheKeyOfTheFile() async throws {
        try file.set("panel_key", to: "option+space")

        let parts = try await spot.items(timeout: 1).parts

        XCTAssertEqual(parts.map(\.id), ["panel_key"])
        XCTAssertEqual(parts.first?.look, .tile)
        XCTAssertEqual(parts.first?.title, "Open Openspot")
        XCTAssertEqual(parts.first?.control, .shortcut("option+space"))
    }

    func testTheSheetShowsTheStandardKeyWithNoFile() async throws {
        let parts = try await spot.items(timeout: 1).parts

        XCTAssertEqual(parts.first?.control, .shortcut("ctrl+space"))
    }

    func testARecordedKeyGoesToTheFileAndTheSheetReadsItAgain() async throws {
        let sheet = SpotSheet(command: try spot)
        sheet.open {}
        for _ in 0..<200 where sheet.panel == nil { try await Task.sleep(for: .milliseconds(5)) }
        let part = try XCTUnwrap(sheet.panel?.parts.first)

        sheet.set(part, to: "cmd+k")

        for _ in 0..<200 where file.read().panelKey != Shortcut(text: "cmd+k") { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertEqual(file.read().panelKey, Shortcut(text: "cmd+k"))
        XCTAssertEqual(sheet.panel?.parts.first?.control, .shortcut("cmd+k"))
    }

    func testAKeyItCannotUseLeavesTheFile() async throws {
        do {
            _ = try await spot.change(SpotAction.set("panel_key", to: "k"), values: "", timeout: 1)
            XCTFail("took a bad key")
        } catch {
            XCTAssertFalse(FileManager.default.fileExists(atPath: file.url.path))
        }
    }

    func testAPartRecordsAKeyAndReportsItsValue() throws {
        var part = try XCTUnwrap(SpotPart(block: TextBlock(fields: [
            .init(key: "part", value: "open"), .init(key: "title", value: "Open"), .init(key: "shortcut", value: "ctrl+k")
        ])))

        XCTAssertEqual(part.value, "ctrl+k")
        part.set("cmd+j")
        XCTAssertEqual(part.control, .shortcut("cmd+j"))
    }

    func testTheCatalogTeachesThePartAndFindsABadKey() {
        XCTAssertTrue(PartCatalog.text.contains("`shortcut="))
        XCTAssertEqual(PluginOutput(text: "part=a\nshortcut=k\n").partFaults, ["the part a needs a shortcut that holds cmd, ctrl or option: k"])
        XCTAssertEqual(PluginOutput(text: "part=a\nshortcut=ctrl+k\n").partFaults, [])
    }
}
