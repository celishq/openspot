import XCTest
@testable import OpenspotCore

@MainActor
final class AttachmentSourceTests: AttachmentCase {
    func testASourceThatTiesPanelOpenToAnAppIsAFaultThatNamesAttachmentPick() async throws {
        try script("tab", toml: "title = 'Tab'\nuses = ['attachment']\n\n[on]\n\"panel.open\" = '^com\\.apple\\.Safari$'", "true")

        await model.reload()

        let faults = try XCTUnwrap(model.entry("tab")?.spot.fault?.faults)
        XCTAssertTrue(faults.contains { $0.contains("\"attachment.pick\" = \"<regex>\"") }, "\(faults)")
        XCTAssertEqual(chips, [])
    }

    func testTheOldAttachKeyIsAnUnknownEvent() async throws {
        try script("tab", toml: "title = 'Tab'\nuses = ['attachment']\n\n[on]\nattach = '^com\\.apple\\.Safari$'", "true")

        await model.reload()

        let faults = try XCTUnwrap(model.entry("tab")?.spot.fault?.faults)
        XCTAssertTrue(faults.contains { $0.contains("unknown event: attach.") && $0.contains("attachment.pick") }, "\(faults)")
    }

    func testPickBrowsersShowsTheChipOverEachBrowserOfOpenspotAndOfTheConfig() async throws {
        let config = folder.appendingPathComponent("config")
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        try "[browsers]\n\"company.thebrowser.dia\" = \"chromium\"\n".write(to: config.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        try taker(takes: "'url'")
        try pickSource(app: "browsers", runs: "true")
        var shown: [[String]] = []

        for app in ["company.thebrowser.dia", "com.apple.Safari", "com.apple.TextEdit"] {
            host.frontApp = FrontApp(bundleID: app)
            await open()
            shown.append(chips.map(\.source))
            model.panelWillHide()
            model.panelDidHide()
        }

        XCTAssertEqual(shown, [["tab"], ["tab"], []])
    }

    func testAHiddenSourceGivesNoChipAndRunsNothingUntilItIsShown() async throws {
        let config = ConfigFile(url: folder.appendingPathComponent("config/config.toml"))
        try FileManager.default.createDirectory(at: config.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try config.change { $0.set(setting: "attachment", of: "tab", to: "false"); $0.set(setting: "attachment", of: "copy", to: "false") }
        try taker(takes: "'text', 'url'")
        try pickSource("tab", runs: "true")
        try source("copy", adds: "text=hola")
        try witness()

        await open()
        try await wait("the spots of the open") { self.log("witness-log").count == 1 }

        XCTAssertEqual(chips, [])
        XCTAssertEqual(log("copy-log"), [])
        XCTAssertEqual(model.entry("copy")?.spot.isOnGrid, false)
        model.panelWillHide()
        model.panelDidHide()

        try config.change { $0.set(setting: "attachment", of: "tab", to: nil); $0.set(setting: "attachment", of: "copy", to: nil) }
        await open()

        try await wait("both chips") { self.chips.count == 2 }
        XCTAssertEqual(Set(chips.map(\.source)), ["tab", "copy"])
    }

    func testASourceThatEndsWithNoValueLeavesNoChip() async throws {
        try taker(takes: "'url'")
        try source(adds: nil)

        await open()

        try await wait("the end of the source") { self.log("done").count == 1 }
        try await wait("no chip") { self.chips.isEmpty }
        XCTAssertEqual(host.notes, [])
    }

    func testAValueThatNoSpotTakesShowsNoChip() async throws {
        try taker(takes: "'text'")
        try source(adds: "url=https://example.com/a")

        await open()

        try await wait("the end of the source") { self.log("done").count == 1 }
        try await wait("no chip") { self.chips.isEmpty }
    }

    func testWhenNoSpotTakesAnyKindNoSourceRuns() async throws {
        try source(adds: "url=https://example.com/a")
        try witness()

        await open()
        try await wait("the spots of the open") { self.log("witness-log").count == 1 }

        XCTAssertEqual(chips, [])
        XCTAssertEqual(log("tab-log"), [])
    }

    func testASourceOfEachOpenShowsNoChipUntilItAnswers() async throws {
        try taker(takes: "'text'")
        try source("copy", waits: true, adds: "text=hola")

        await open()

        XCTAssertEqual(chips, [])
        FileManager.default.createFile(atPath: path("release"), contents: Data())
        try await wait("the copy") { !self.chips.isEmpty }
        XCTAssertEqual(chips.map(\.source), ["copy"])
        XCTAssertEqual(chips.map(\.app), [nil])
        XCTAssertEqual(chips.map(\.state), [.ready(AttachmentValue(text: "hola"))])
    }

    func testAChipOfTheFrontAppShowsTheAppsIconAndAnotherChipItsSpotsSymbol() async throws {
        host.frontApp = FrontApp(bundleID: "com.apple.Safari", path: "/Applications/Safari.app")
        try taker(takes: "'text', 'url'")
        try pickSource("tab", waits: true, runs: "\(cli) attachment add url=https://example.com/a")
        try source("copy", adds: "text=hola")

        await open()

        XCTAssertEqual(chips.map(\.look), [.file(FileIcon(path: "/Applications/Safari.app"))])
        try await wait("the copy") { self.chips.count == 2 }
        let symbol = try XCTUnwrap(model.entry("copy")?.spot.symbol)
        XCTAssertEqual(chips.first { $0.source == "copy" }?.look, .symbol(symbol))
        XCTAssertTrue(model.handleKey(ActionKey(name: "tab")))
        FileManager.default.createFile(atPath: path("release"), contents: Data())
        try await wait("the tab") { self.chips.allSatisfy { $0.value != nil } }
        XCTAssertEqual(chips.first { $0.source == "tab" }?.look, .file(FileIcon(path: "/Applications/Safari.app")))
    }

    func testASourceIsOffTheGridAndOutOfTheSearch() async throws {
        try taker(takes: "'url'")
        try source(adds: nil)

        await open()
        model.query = "tab"

        XCTAssertFalse(model.cards.filter(\.isOnGrid).contains { $0.id == "tab" })
        XCTAssertFalse(model.visible.contains { $0.spot.id == "tab" })
    }

    func testFilesAreReadForTheirKindsWhenTheyArrive() async throws {
        let movie = path("a.mov")
        FileManager.default.createFile(atPath: movie, contents: Data())
        try taker(takes: "'mov'")
        try source("finder", adds: "file='\(movie)' file='\(path("gone.mov"))'")
        host.frontApp = FrontApp(bundleID: "com.apple.finder")

        await open()

        try await wait("the files") { self.log("done").count == 1 }
        XCTAssertEqual(log("done"), ["0"])
        try await wait("no chip, since one file is gone") { self.chips.isEmpty }
    }

    func testAValueThatArrivesWhileThePanelShowsLandsAtTheEndOfTheShowInAFade() async throws {
        model.showLength = 600
        try taker(takes: "'url'")
        try source(adds: "url=https://example.com/a")

        await open()

        try await wait("the value") { !self.model.heldArrivals.isEmpty || !self.chips.isEmpty }
        XCTAssertTrue(chips.isEmpty)
        let changes = host.motions.count
        model.endShowMotion()
        XCTAssertEqual(chips.first?.value?.payload, .url("https://example.com/a"))
        XCTAssertEqual(host.motions.dropFirst(changes).first, .fade)
    }

    func testAValueOfTwoKindsFailsWithExit2() async throws {
        try taker(takes: "'url'")
        try source(adds: "url=https://example.com text=hola")

        await open()

        try await wait("the end of the source") { self.log("done").count == 1 }
        XCTAssertEqual(log("done"), ["2"])
        XCTAssertEqual(log("errors"), ["`openspot attachment add` takes one kind of value: file= once for each file, url= or text=."])
    }

    func testAPanelOpenRegexKeepsAnOrdinarySpotToItsApp() async throws {
        try script("finder", toml: "title = 'Finder'\n\n[on]\n\"panel.open\" = '^com\\.apple\\.finder$'", """
        case "$1" in
          show) echo show >> '\(path("finder-log"))'; printf 'text=x\\ntitle=Finder\\n' ;;
        esac
        """)
        try witness()

        await open()
        try await wait("the spots of the open") { self.log("witness-log").count == 1 }

        XCTAssertEqual(log("finder-log"), [])
    }
}
