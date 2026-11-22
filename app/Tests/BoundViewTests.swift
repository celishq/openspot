import XCTest
@testable import OpenspotCore

@MainActor
final class BoundViewTests: PanelCase {
    private var client: URL!

    override func setUp() async throws {
        try await super.setUp()
        client = folder.appendingPathComponent("A.app/Contents/Helpers/openspot")
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: client)
        takeCalls()
        try script("picker", toml: "title = 'Picker'\n[actions.pick]\noutputs.until = 'text'", """
        case "$1" in
          show) printf 'text=s\\ntitle=Show\\n' ;;
          pick) printf 'frame=\\n\\ntext=morning\\ntitle=Morning\\n\\ntext=evening\\ntitle=Evening\\n' ;;
          open) echo "out.until=$2" ;;
        esac
        """)
        try script("asker", toml: "title = 'Asker'\n[bindings]\npicker = { spot = 'picker' }", """
        case "$1" in
          show) printf 'text=x\\ntitle=Asker\\n' ;;
          *) '\(client.path)' run picker.pick --out until > '\(path("out"))' 2> '\(path("errors"))'; echo $? >> '\(path("done"))' ;;
        esac
        """)
        await model.reload()
    }

    private func path(_ name: String) -> String {
        folder.appendingPathComponent(name).path
    }

    private func log(_ name: String) -> [String] {
        ((try? String(contentsOfFile: path(name), encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    private func runPick() async throws {
        try XCTUnwrap(model.sheets["asker"]).pressCard()
        try await wait("the pushed view of the action") { self.model.transition.phase == .open && self.titles == ["Morning", "Evening"] }
    }

    func testAnActionThatAnswersWithAViewPushesItAndTheRunEndsWithTheValuesOfAPressInIt() async throws {
        try await runPick()

        XCTAssertEqual(model.openSheetID, "picker")
        model.sheets["picker"]?.list.select(run: "evening")
        model.runSelectedItem()

        try await wait("the end of the run") { self.log("done").count == 1 }
        XCTAssertEqual(log("done"), ["0"], log("errors").joined(separator: "\n"))
        XCTAssertEqual(log("out"), ["evening"])
        try await wait("the pushed view gone") { self.model.openSheetID != "picker" }
    }

    func testClosingThePushedViewCancelsTheRunWithExit4() async throws {
        try await runPick()

        XCTAssertTrue(model.handleKey(toGrid))

        try await wait("the end of the run") { self.log("done").count == 1 }
        XCTAssertEqual(log("done"), ["4"])
        XCTAssertEqual(log("out"), [])
    }
}
