import XCTest
@testable import OpenspotCore

@MainActor
final class ContextSourceTests: PanelCase {
    private var client: URL!

    override func setUp() async throws {
        try await super.setUp()
        client = folder.appendingPathComponent("A.app/Contents/Helpers/openspot")
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: client)
        takeCalls()
        host.frontApp = "com.apple.Safari"
    }

    private func path(_ name: String) -> String {
        folder.appendingPathComponent(name).path
    }

    private func log(_ name: String) -> [String] {
        ((try? String(contentsOfFile: path(name), encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    private func source(_ name: String = "tab", app: String? = "^com\\.apple\\.Safari$", waits: Bool = false, adds words: String?) throws {
        let open = app.map { "'\($0)'" } ?? "true"
        let wait = waits ? "while [ ! -f '\(path("release"))' ]; do sleep 0.02; done\n" : ""
        let add = words.map { "'\(client.path)' context add \($0) 2>> '\(path("errors"))'; echo $? >> '\(path("done"))'" } ?? "echo 0 >> '\(path("done"))'"
        try script(name, toml: "title = '\(name)'\nuses = ['context']\n\n[on]\n\"panel.open\" = \(open)", """
        case "$1" in
          show) echo show >> '\(path("\(name)-log"))'; \(wait)\(add) ;;
        esac
        """)
    }

    private func taker(_ name: String = "keep", takes kinds: String) throws {
        try script(name, toml: "title = '\(name)'\n\n[on]\ndrop = [\(kinds)]", """
        case "$1" in
          show) printf 'text=x\\ntitle=\(name)\\n' ;;
          drop) grep '^input\\.' >> '\(path("\(name)-drops"))' ;;
        esac
        """)
    }

    private func witness() throws {
        try script("witness", toml: "title = 'Witness'\n\n[on]\n\"panel.open\" = true", """
        case "$1" in
          show) echo show >> '\(path("witness-log"))'; printf 'text=x\\ntitle=Witness\\n' ;;
        esac
        """)
    }

    private func open() async {
        await model.reload()
        model.isShown = true
        model.panelWillShow()
    }

    private var chips: [ContextChip] {
        model.context.chips
    }

    func testASourceOverItsAppShowsALoadingChipAtTheOpenAndItsValueWhenItAnswers() async throws {
        try taker(takes: "'url'")
        try source(waits: true, adds: "url=https://example.com/a title=A")

        await open()

        XCTAssertEqual(chips, [ContextChip(source: "tab", app: "com.apple.Safari")])
        FileManager.default.createFile(atPath: path("release"), contents: Data())
        try await wait("the value of the tab") { self.chips.first?.value != nil }
        XCTAssertEqual(chips, [ContextChip(source: "tab", app: "com.apple.Safari", value: ContextValue(url: "https://example.com/a", title: "A"))])
        XCTAssertEqual(log("errors"), [])
        XCTAssertEqual(host.notes, [])
    }

    func testASourceOverAnotherAppDoesNotRunAndShowsNoChip() async throws {
        try taker(takes: "'url'")
        try source(adds: "url=https://example.com/a")
        try witness()
        host.frontApp = "com.apple.finder"

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
        XCTAssertEqual(chips, [ContextChip(source: "copy", app: nil, value: ContextValue(text: "hola"))])
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
        model.landSearch()

        XCTAssertFalse(model.cards.filter(\.isOnGrid).contains { $0.id == "tab" })
        XCTAssertFalse(model.visible.contains { $0.spot.id == "tab" })
    }

    func testFilesAreReadForTheirKindsWhenTheyArrive() async throws {
        let movie = path("a.mov")
        FileManager.default.createFile(atPath: movie, contents: Data())
        try taker(takes: "'mov'")
        try source("finder", app: "^com\\.apple\\.finder$", adds: "file='\(movie)' file='\(path("gone.mov"))'")
        host.frontApp = "com.apple.finder"

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
        XCTAssertEqual(log("errors"), ["`openspot context add` takes one kind of value: file= once for each file, url= or text=."])
    }
}
