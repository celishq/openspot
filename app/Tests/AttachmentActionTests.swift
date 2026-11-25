import XCTest
@testable import OpenspotCore

@MainActor
final class AttachmentActionTests: AttachmentCase {
    private let tab = ActionKey(name: "tab")
    private let pull = "https://github.com/o/r/pull/12"
    private let pullPattern = "^https://github\\\\.com/.+/pull/\\\\d+"

    private func actionSpot(_ name: String, title: String, actions: [(id: String, title: String, extra: String)], drop: Bool = false) throws {
        let tables = actions.map { "[actions.\($0.id)]\ntitle = '\($0.title)'\n\($0.extra)" }.joined(separator: "\n")
        let on = drop ? "\n[on]\ndrop = ['mov']" : ""
        try script(name, toml: "title = '\(title)'\n\(tables)\(on)", """
        case "$1" in
          drop) grep '^input\\.' | sed 's/^/drop /' >> '\(path("\(name)-log"))' ;;
          show|"") printf 'text=x\\ntitle=\(title)\\n' ;;
          *) { echo "$1"; grep '^input\\.'; } >> '\(path("\(name)-log"))' ;;
        esac
        """)
    }

    private func url(pattern: String? = nil, more: String = "") -> String {
        let pattern = pattern.map { ", pattern = \"\($0)\"" } ?? ""
        return "inputs.url = { type = 'url', required = true\(pattern) }\n\(more)"
    }

    private func openPull() async throws {
        try source(adds: "url=\(pull) title=Fix")
        await open()
        try await wait("the value of the tab") { self.chips.first?.value != nil }
        XCTAssertTrue(model.handleKey(tab))
    }

    private var movie: String {
        path("a.mov")
    }

    private func file(more: String = "") -> String {
        "inputs.file = { type = 'file', required = true }\n\(more)"
    }

    private func openMovie() async throws {
        FileManager.default.createFile(atPath: movie, contents: Data())
        try source("finder", adds: "file='\(movie)'")
        host.frontApp = FrontApp(bundleID: "com.apple.finder")
        await open()
        try await wait("the value of the file") { self.chips.first?.value != nil }
        XCTAssertTrue(model.handleKey(tab))
    }

    private var shown: [String] {
        model.visible.map(\.state.title)
    }

    private var details: [String] {
        model.visible.map { $0.state.subtitle ?? "" }
    }

    func testADropRowShowsTheTitleAndTheDetailOfItsSpot() async throws {
        try taker("keep", detail: "Keep a page", takes: "'mov'")
        try taker("bare", takes: "'mov'")

        try await openMovie()

        XCTAssertEqual(Set(model.visible.map { "\($0.state.title) \($0.state.subtitle ?? "none")" }), ["keep Keep a page", "bare none"])
    }

    func testAnActionWhosePatternMatchesShowsWithItsTitleAndSpot() async throws {
        try actionSpot("review", title: "Review", actions: [("approve", "Approve", url(pattern: pullPattern, more: "icon = 'checkmark'"))])

        try await openPull()

        XCTAssertEqual(shown, ["Approve"])
        XCTAssertEqual(details, ["Review"])
        XCTAssertEqual(model.visible.first?.symbol, "checkmark")
    }

    func testAnActionOfferedToAttachmentsShowsOnlyOnAChip() async throws {
        try actionSpot("pages", title: "Pages", actions: [("save", "Save page", url(more: "offers = ['attachments']"))])
        try await openPull()
        XCTAssertEqual(shown, ["Save page"])
        XCTAssertTrue(model.handleKey(escape))
        let pages = try XCTUnwrap(model.entries.first { $0.id == "pages" })

        model.openMenu(on: SpotsModel.Target(entry: pages, item: nil))
        let menu = model.menu?.rows.map(\.title) ?? []
        model.closeMenu()
        model.query = "save page"

        XCTAssertFalse(menu.isEmpty)
        XCTAssertFalse(menu.contains("Save page"))
        XCTAssertFalse(shown.contains("Save page"))
        XCTAssertTrue(pages.isOnGrid)
        XCTAssertEqual(pages.spot.mainAct, .sheet)
    }

    func testAnActionWhosePatternDoesNotMatchShowsNoRow() async throws {
        try actionSpot("issues", title: "Issues", actions: [("close", "Close issue", url(pattern: "^https://github\\\\.com/.+/issues/\\\\d+"))])
        try taker(takes: "'url'")

        try await openPull()

        XCTAssertEqual(shown, ["keep"])
    }

    func testAnActionThatNeedsAnotherInputOrHasNoTitleShowsNoRow() async throws {
        try actionSpot("notes", title: "Notes", actions: [
            ("file", "File", url(more: "inputs.folder = { type = 'text', required = true }")),
            ("read", "Read", "inputs.text = { type = 'text', required = true }"),
        ])
        try script("bare", toml: "title = 'Bare'\n[actions.save]\n\(url())", "true")
        try taker(takes: "'url'")

        try await openPull()

        XCTAssertEqual(shown, ["keep"])
    }

    func testPatternedActionsComeFirstThenActionsByKindUpToFive() async throws {
        try actionSpot("pages", title: "Pages", actions: [("save", "Save page", url()), ("share", "Share page", url()), ("print", "Print page", url())])
        try actionSpot("review", title: "Review", actions: [("approve", "Approve", url(pattern: pullPattern)), ("merge", "Merge", url(pattern: pullPattern))])

        try await openPull()

        XCTAssertEqual(shown, ["Approve", "Merge", "Save page", "Share page", "Print page"])
        XCTAssertEqual(details, ["Review", "Review", "Pages", "Pages", "Pages"])
    }

    func testDropRowsComeAfterTheActionsOfAFileUpToFive() async throws {
        try actionSpot("clips", title: "Clips", actions: [("cut", "Cut", file()), ("trim", "Trim", file()), ("play", "Play", file()), ("mute", "Mute", file())])
        for name in ["keep", "save"] { try taker(name, takes: "'mov'") }

        try await openMovie()

        XCTAssertEqual(shown, ["Cut", "Trim", "Play", "Mute", "keep"])
    }

    func testASpotWhoseActionShowsDoesNotAlsoShowItsDrop() async throws {
        try actionSpot("clips", title: "Clips", actions: [("cut", "Cut", file())], drop: true)
        try taker(takes: "'mov'")

        try await openMovie()

        XCTAssertEqual(shown, ["Cut", "keep"])
    }

    func testReturnOnADropRowRunsTheDropWithTheFile() async throws {
        try taker(takes: "'mov'")
        try await openMovie()

        model.runSelected()

        try await wait("the drop") { self.log("keep-drops").count == 1 }
        XCTAssertEqual(log("keep-drops"), ["input.file=\(movie)"])
        XCTAssertFalse(model.attachments.isOn)
    }

    func testReturnRunsTheActionWithTheValueAndTheTitleOfTheChip() async throws {
        try actionSpot("review", title: "Review", actions: [("approve", "Approve", url(pattern: pullPattern, more: "inputs.title = 'text'"))])
        try await openPull()
        let row = try XCTUnwrap(model.visible.firstIndex { $0.state.title == "Approve" })
        model.selected = row

        model.runSelected()

        try await wait("the action") { self.log("review-log").count == 3 }
        XCTAssertEqual(log("review-log"), ["approve", "input.url=\(pull)", "input.title=Fix"])
        XCTAssertFalse(model.attachments.isOn)
        XCTAssertEqual(host.dismissals, 1)
    }

    func testAnActionWithNoTitleInputGetsOnlyItsValue() async throws {
        try actionSpot("pages", title: "Pages", actions: [("save", "Save page", url())])
        try await openPull()

        model.runSelected()

        try await wait("the action") { self.log("pages-log").count == 2 }
        XCTAssertEqual(log("pages-log"), ["save", "input.url=\(pull)"])
    }

    func testAnActionWithConfirmRunsOnTheSecondReturn() async throws {
        try actionSpot("review", title: "Review", actions: [("approve", "Approve", url(pattern: pullPattern, more: "confirm = 'Press again to approve'"))])
        try await openPull()

        XCTAssertTrue(model.handleSearchKey(ActionKey(name: "return")))

        XCTAssertEqual(model.hint, "⏎ Press again to approve   ⇥ Next   Esc Leave")
        XCTAssertTrue(model.attachments.isOn)
        XCTAssertEqual(log("review-log"), [])

        XCTAssertTrue(model.handleSearchKey(ActionKey(name: "return")))

        try await wait("the action") { self.log("review-log").first == "approve" }
        XCTAssertFalse(model.attachments.isOn)
    }

    func testTypingFiltersTheActionRows() async throws {
        try actionSpot("pages", title: "Pages", actions: [("save", "Save page", url()), ("share", "Share page", url())])
        try await openPull()

        model.query = "shar"

        XCTAssertEqual(shown, ["Share page"])
        XCTAssertEqual(model.details?.label, "Fix")
    }

    func testASlashWordWhileActionRowsShowRunsItsCommand() async throws {
        try script("translate", toml: "title = 'Translate'\n\n[on]\ncommand = ['translate']", """
        case "$1" in
          command) echo command >> '\(path("translate-log"))' ;;
          *) printf 'text=x\\ntitle=Translate\\n' ;;
        esac
        """)
        try actionSpot("pages", title: "Pages", actions: [("save", "Save page", url())])
        try await openPull()

        model.query = "/translate hola"
        model.runSelected()

        try await wait("the command") { self.log("translate-log") == ["command"] }
        XCTAssertEqual(log("pages-log"), [])
    }

    func testEscLeavesTheActionRows() async throws {
        try actionSpot("pages", title: "Pages", actions: [("save", "Save page", url())])
        try await openPull()

        XCTAssertTrue(model.handleKey(escape))

        XCTAssertFalse(model.attachments.isOn)
        XCTAssertFalse(shown.contains("Save page"))
        XCTAssertEqual(host.dismissals, 0)
    }

    func testCommandKOnAnActionRowOpensNoMenu() async throws {
        try actionSpot("pages", title: "Pages", actions: [("save", "Save page", url())])
        try await openPull()

        _ = model.handleKey(ActionKey(name: "k", isCommand: true))

        XCTAssertNil(model.menu)
        XCTAssertTrue(model.attachments.isOn)
    }

    func testAReopenShowsTheGridAndNoActionRows() async throws {
        try actionSpot("pages", title: "Pages", actions: [("save", "Save page", url())])
        try await openPull()

        model.panelWillHide()
        model.panelDidHide()
        model.panelWillShow()

        XCTAssertFalse(model.attachments.isOn)
        XCTAssertFalse(shown.contains("Save page"))
        XCTAssertNil(model.details)
    }
}
