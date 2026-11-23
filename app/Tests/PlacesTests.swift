import XCTest
@testable import OpenspotCore

@MainActor
final class PlacesTests: PanelCase {
    private func entry(_ id: String) throws -> SpotsModel.Entry {
        try XCTUnwrap(model.entries.first { $0.id == id })
    }

    private func logged(_ name: String) -> String {
        "echo \"$1\" >> '\(folder.appendingPathComponent(name).path)'"
    }

    private func log(_ name: String) -> [String] {
        ((try? String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    func testASpotWithNoOffersCanBeACardInTheMenuBarAFloatAndAWindow() async throws {
        try script("shelf", toml: "title = 'Shelf'", "printf 'text=a\\ntitle=A\\n'")
        _ = try model.files.config.change { $0.arrangement.set(isInMenuBar: true, of: "shelf") }
        await model.reload()

        XCTAssertTrue(try entry("shelf").isOnGrid)
        XCTAssertEqual(model.menuBarMarks.map(\.id), ["shelf"])
        let settings = try XCTUnwrap(try entry("shelf").spot.settingsSheet)
        XCTAssertEqual(settings.keys.map(\.act), [.open, .float])
        XCTAssertTrue(settings.sheet(in: model.config, secrets: [:]).contains("title=Open in a window"))
        model.float("shelf")
        XCTAssertEqual(host.floats, ["shelf"])
        model.land("shelf")

        _ = try model.files.config.change { $0.arrangement.set(isWindow: true, of: "shelf") }
        await model.reload()
        model.press("shelf")

        XCTAssertEqual(host.windows, ["shelf"])
    }

    func testAnOldPlaceInOffersIsAnUnknownKeyAndOnlySearchInOnStays() throws {
        for place in ["card", "menubar", "float", "window", "none"] {
            try script(place, toml: "offers = ['\(place)']", "")
        }
        try script("found", toml: "[on]\nsearch = true", "")

        let scan = try SpotsFolder(url: spots).scan()

        XCTAssertEqual(scan.spots.map(\.id), ["found"])
        XCTAssertEqual(Set(scan.refused.map(\.file)), ["card", "menubar", "float", "window", "none"])
    }

    func testACardOfOtherSpotsPressAndToAreUnknownKeysSoTheSpotDoesNotLoad() throws {
        try script("cups", toml: "[on]\nevery = 60", "")
        try script("board", toml: "'grid.large' = ['cups cups']\nto = 'cups'", "")
        try script("pressed", toml: "press = 'open'", "")
        try script("led", toml: "to = 'cups'", "")

        let scan = try SpotsFolder(url: spots).scan()

        XCTAssertEqual(scan.spots.map(\.id), ["cups"])
        XCTAssertEqual(Set(scan.refused.map(\.file)), ["board", "pressed", "led"])
    }

    func testReturnOnASpotWithNoCommandOpensItsSheetWhichAsksShowThoughItListsNoSheetOpen() async throws {
        try script("plain", toml: "title = 'Plain'", logged("plain"))
        try script("counted", toml: "title = 'Counted'\n[on]\n\"panel.open\" = true", "\(logged("counted"))\nexit 0")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        try await wait("the panel read") { self.log("counted") == ["show"] && !self.model.runs.isShowing }

        model.press("plain")
        try await wait("the sheet of plain") { self.model.openSheetID == "plain" }
        model.closeSheet(moving: false)
        model.run(try entry("counted"))
        try await wait("the sheet of counted") { self.model.openSheetID == "counted" }

        XCTAssertEqual(log("plain"), ["show"])
        XCTAssertFalse(log("counted").contains("press"))
    }

    func testACardPressTheOpenKeyAndABareSlashCommandAllRunTheOneCommand() async throws {
        try script("wipe", toml: "title = 'Wipe'\n[actions.wipe]\ntitle = 'Wipe'\n[on]\n\"sheet.open\" = true\ncommand = ['wipe']", "[ \"$1\" = show ] && { printf 'text=a\\ntitle=A\\n'; exit 0; }\n\(logged("wipe"))")
        _ = try model.files.config.change {
            $0.assign(.tap(.option), to: "wipe", act: .command("wipe"))
            $0.arrangement.set(isOnGrid: true, of: "wipe")
        }
        await model.reload()
        model.isShown = true
        model.panelWillShow()

        model.tap("wipe")
        try await wait("the press") { self.log("wipe") == ["wipe"] }
        model.press(GlobalKey(spot: "wipe", act: .open, trigger: .key(try XCTUnwrap(Shortcut(text: "ctrl+option+w")))))
        try await wait("the open key") { self.log("wipe") == ["wipe", "wipe"] }
        model.isShown = true
        model.panelWillShow()
        model.query = "/wipe"
        model.landSearch()
        model.selected = 0
        model.runSelected()

        try await wait("the slash command") { self.log("wipe") == ["wipe", "wipe", "command"] }
        XCTAssertNil(model.openSheetID)
    }

    func testACardPressAndTheOpenKeyOpenTheSheetOfASpotWithNoCommand() async throws {
        try script("note", toml: "title = 'Note'", logged("note"))
        _ = try model.files.config.change { $0.arrangement.set(isOnGrid: true, of: "note") }
        await model.reload()
        model.isShown = true
        model.panelWillShow()

        model.tap("note")
        try await wait("the sheet from the card") { self.model.openSheetID == "note" }
        model.closeSheet(moving: false)
        model.press(GlobalKey(spot: "note", act: .open, trigger: .key(try XCTUnwrap(Shortcut(text: "ctrl+option+n")))))
        try await wait("the sheet from the open key") { self.model.openSheetID == "note" }

        XCTAssertFalse(log("note").contains("press"))
    }

    func testAClickOnAMenuBarItemOpensTheSheetUnderIt() async throws {
        try script("cups", toml: "title = 'Cups'\n[actions.pour]\ntitle = 'Pour'\n[on]\n\"sheet.open\" = true", "printf 'text=a\\ntitle=A\\n'")
        _ = try model.files.config.change { $0.arrangement.set(isInMenuBar: true, of: "cups") }
        await model.reload()

        model.openFromMenuBar("cups")

        XCTAssertEqual(host.floats, ["cups"])
        XCTAssertNil(model.recording)
    }

    func testOpenspotAsksASpotOnlyWhileACardOfItShowsOnTheGrid() async throws {
        try script("shown", toml: "[on]\nevery = 600", "\(logged("shown"))\nprintf 'text=a\\ntitle=1\\n'")
        try script("hidden", toml: "[on]\nevery = 600", "\(logged("hidden"))\nprintf 'text=a\\ntitle=1\\n'")
        _ = try model.files.config.change {
            $0.arrangement.set(isOnGrid: true, of: "shown")
            $0.arrangement.set(isOnGrid: false, of: "hidden")
        }
        await model.reload()
        XCTAssertEqual(log("shown"), [])

        model.isShown = true
        model.panelWillShow()

        try await wait("the read of the card") { self.log("shown").count == 1 && !self.model.runs.isShowing }
        XCTAssertEqual(log("shown"), ["every"])
        XCTAssertEqual(log("hidden"), [])
    }
}
