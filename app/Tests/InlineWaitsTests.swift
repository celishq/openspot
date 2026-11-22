import XCTest
@testable import OpenspotCore

@MainActor
final class InlineWaitsTests: PanelCase {
    override func setUp() async throws {
        try await super.setUp()
        model.quit()
        let host = host!
        model = SpotsModel(host: host, files: model.files, runs: SpotRuns(showLimit: 0.3, stopPause: stopPause, prepare: { await host.prepare($0, glyphs: $1) }))
        host.model = model
        takeCalls()
        try script("picker", toml: "title = 'Picker'\n[actions.pick]\noutputs.until = 'text'", """
        case "$1" in
          show) printf 'text=s\\ntitle=Show\\n' ;;
          pick) printf 'frame=\\n\\ntext=morning\\ntitle=Morning\\n\\ntext=evening\\ntitle=Evening\\n' ;;
          press) echo "out.until=$(sed -n 's/^input.item=//p')" ;;
        esac
        """)
        try script("logger", toml: "title = 'Logger'\n[actions.write]\ninputs.line = 'text'", """
        case "$1" in write) sed -n 's/^input.line=//p' >> '\(path("heard"))' ;; esac
        """)
        let url = spots.spotFile("asker", extension: "js")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        export default {
          async show() { return "text=x\\ntitle=Asker\\n" },
          async press(input, env) {
            const picked = await env.picker.pick()
            await env.logger.write({ line: picked ? picked.until : "none" })
          },
        }
        """.write(to: url, atomically: true, encoding: .utf8)
        try "title = 'Asker'\n[bindings]\npicker = { spot = 'picker' }\nlogger = { spot = 'logger' }".write(to: url.deletingLastPathComponent().appendingPathComponent(Manifest.fileName), atomically: true, encoding: .utf8)
        await model.reload()
    }

    private func path(_ name: String) -> String {
        folder.appendingPathComponent(name).path
    }

    private func log(_ name: String) -> [String] {
        ((try? String(contentsOfFile: path(name), encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    func testAHandlerThatAwaitsAPushedViewPastItsLimitEndsWellAndItsSpotAnswersMeanwhile() async throws {
        let asker = try XCTUnwrap(model.sheets["asker"])
        asker.pressCard()
        try await wait("the pushed view of the action") { self.model.transition.phase == .open && self.titles == ["Morning", "Evening"] }

        let started = Date()
        let shown = try await model.runs.answer(of: asker.spot, .show, limit: 5)
        XCTAssertEqual(TextBlock.blocks(in: shown).first?.value("title"), "Asker")
        XCTAssertLessThan(Date().timeIntervalSince(started), 1)
        try await wait("a wait past the limit") { Date().timeIntervalSince(started) > 1 }
        model.sheets["picker"]?.list.select(run: "evening")
        model.runSelectedItem()

        try await wait("the end of the handler") { self.log("heard") == ["evening"] }
    }
}
