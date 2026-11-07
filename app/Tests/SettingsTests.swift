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

        XCTAssertEqual(commands.map(\.name), ["Spots", "Settings", "Build"])
        XCTAssertEqual(commands.map(\.key?.name), ["p", nil, nil])
    }

    func testTheSheetListsTheKeyOfTheFile() async throws {
        try file.set("panel_key", to: "option+space")

        let items = try await spot.items(timeout: 1).items

        XCTAssertEqual(items.map(\.run), ["panel_key"])
        XCTAssertEqual(items.first?.title, "Open Openspot")
        XCTAssertEqual(items.first?.shortcut, "option+space")
    }

    func testTheSheetListsTheStandardKeyWithNoFile() async throws {
        let items = try await spot.items(timeout: 1).items

        XCTAssertEqual(items.first?.shortcut, "ctrl+space")
    }

    func testTheSheetHasNoPartsAndKeepsItsOrder() async throws {
        let output = try await spot.items(timeout: 1)

        XCTAssertTrue(output.parts.isEmpty)
        XCTAssertFalse(output.keepsRecent)
    }

    func testAKeyRecordedOnARowGoesToTheFileAndTheListReadsItAgain() async throws {
        let runs = SpotRuns()
        let sheet = runs.sheet(for: try spot)
        sheet.open {}
        for _ in 0..<200 where sheet.list.shown.isEmpty { try await Task.sleep(for: .milliseconds(5)) }
        let item = try XCTUnwrap(sheet.list.selectedItem)

        sheet.set(item, to: "cmd+k")

        for _ in 0..<200 where sheet.list.shown.first?.shortcut != "cmd+k" { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertEqual(file.read().panelKey, Shortcut(text: "cmd+k"))
        XCTAssertEqual(sheet.list.shown.first?.shortcut, "cmd+k")
    }

    func testARowCarriesItsKey() {
        let items = PluginOutput(text: "row=Open\nrun=open\nshortcut=ctrl+k\n\nrow=Other\nrun=other\n").items

        XCTAssertEqual(items.map(\.shortcut), ["ctrl+k", nil])
    }

    func testAKeyItCannotUseLeavesTheFile() async throws {
        do {
            _ = try await SpotRuns().answer(of: spot, .set("panel_key", to: "k"), input: "", limit: 1)
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
