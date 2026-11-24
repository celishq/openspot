import XCTest
@testable import OpenspotCore

@MainActor
final class AttachmentSourceTests: AttachmentCase {
    func testASourceOverItsAppShowsALoadingChipAtTheOpenAndItsValueWhenItAnswers() async throws {
        try taker(takes: "'url'")
        try source(waits: true, adds: "url=https://example.com/a title=A")

        await open()

        XCTAssertEqual(chips.map(\.source), ["tab"])
        XCTAssertEqual(chips.map(\.app), ["com.apple.Safari"])
        XCTAssertEqual(chips.map(\.state), [.loading])
        FileManager.default.createFile(atPath: path("release"), contents: Data())
        try await wait("the value of the tab") { self.chips.first?.value != nil }
        XCTAssertEqual(chips.map(\.state), [.ready(AttachmentValue(url: "https://example.com/a", title: "A"))])
        XCTAssertEqual(chips.map(\.app), ["com.apple.Safari"])
        XCTAssertEqual(log("errors"), [])
        XCTAssertEqual(host.notes, [])
    }

    func testASourceOverAnotherAppDoesNotRunAndShowsNoChip() async throws {
        try taker(takes: "'url'")
        try source(adds: "url=https://example.com/a")
        try witness()
        host.frontApp = FrontApp(bundleID: "com.apple.finder")

        await open()
        try await wait("the spots of the open") { self.log("witness-log").count == 1 }

        XCTAssertEqual(chips, [])
        XCTAssertEqual(log("tab-log"), [])
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

    func testASourceWithNoAppShowsNoLoadingChipAndItsChipWhenItAnswers() async throws {
        try taker(takes: "'text'")
        try source("copy", app: nil, waits: true, adds: "text=hola")

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
        try source("tab", waits: true, adds: "url=https://example.com/a")
        try source("copy", app: nil, adds: "text=hola")

        await open()

        XCTAssertEqual(chips.map(\.look), [.file(FileIcon(path: "/Applications/Safari.app"))])
        try await wait("the copy") { self.chips.count == 2 }
        let symbol = try XCTUnwrap(model.entry("copy")?.spot.symbol)
        XCTAssertEqual(chips.first { $0.source == "copy" }?.look, .symbol(symbol))
        FileManager.default.createFile(atPath: path("release"), contents: Data())
        try await wait("the tab") { self.chips.allSatisfy { !$0.isLoading } }
        XCTAssertEqual(chips.first { $0.source == "tab" }?.look, .file(FileIcon(path: "/Applications/Safari.app")))
    }

    func testChipsOfTheFrontAppComeFirstWithTextFirst() async throws {
        try taker(takes: "'text', 'url'")
        try source("copy", app: nil, adds: "text=copied")
        try source("tab", adds: "url=https://example.com/a")
        try source("selection", adds: "text=hola app=com.apple.Safari")

        await open()

        try await wait("three values") { self.chips.count == 3 && self.chips.allSatisfy { $0.value != nil } }
        XCTAssertEqual(chips.map(\.source), ["selection", "tab", "copy"])
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
        try source("finder", app: "^com\\.apple\\.finder$", adds: "file='\(movie)' file='\(path("gone.mov"))'")
        host.frontApp = FrontApp(bundleID: "com.apple.finder")

        await open()

        try await wait("the files") { self.log("done").count == 1 }
        XCTAssertEqual(log("done"), ["0"])
        try await wait("no chip, since one file is gone") { self.chips.isEmpty }
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
