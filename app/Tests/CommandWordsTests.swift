import XCTest
@testable import OpenspotCore

final class CommandWordsTests: PanelCase {
    private var sent: URL {
        folder.appendingPathComponent("sent")
    }

    override func setUp() async throws {
        try await super.setUp()
        try script("snooze", toml: "title = 'Snooze'\n[on]\ncommand = ['snooze', 'later']", """
        [ "$1" = command ] && grep '^input\\.' | tr '\\n' ' ' >> '\(sent.path)'
        exit 0
        """)
    }

    private func open() async {
        await model.reload()
        model.isShown = true
        model.panelWillShow()
    }

    private func type(_ query: String) {
        model.query = query
    }

    func testTheCommandWordsOfTheSpotAreItsDefaults() async throws {
        await open()

        type("/")

        XCTAssertEqual(Set(model.visible.map(\.state.title)), ["snooze", "later"])
    }

    func testTheConfigRenamesOrRemovesEachWordAndTheSpotStillGetsItsOwnName() async throws {
        try FileManager.default.createDirectory(at: model.files.config.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "[[spots]]\nid = \"snooze\"\ncommands = { snooze = \"sz\", later = \"\" }\n".write(to: model.files.config.url, atomically: true, encoding: .utf8)
        await open()

        type("/")
        XCTAssertEqual(model.visible.map(\.state.title), ["sz"])
        type("/sz tomorrow")
        model.runSelected()

        try await wait("the command") { ((try? String(contentsOf: self.sent, encoding: .utf8)) ?? "") == "input.name=snooze input.text=tomorrow " }
    }

    func testTheConfigKeepsTheRenamesWhenItIsWrittenAgain() throws {
        let config = Config(text: "[[spots]]\nid = \"snooze\"\ncommands = { snooze = \"sz\" }\n")

        XCTAssertEqual(config.faults, [])
        XCTAssertEqual(Config(text: config.text).arrangement.commands(of: "snooze"), ["snooze": "sz"])
    }
}
