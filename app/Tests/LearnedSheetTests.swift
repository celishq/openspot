import XCTest
@testable import OpenspotCore

@MainActor
final class LearnedSheetTests: PanelCase {
    override var learnsSheets: Bool {
        true
    }

    private func spot(_ name: String, toml: String, show: String) throws {
        takeCalls()
        try script(name, toml: toml, """
        in=$(cat); ev=$(printf '%s\\n' "$in" | sed -n 's/^event=//p')
        echo "$1 $ev" >> '\(log.path)'
        case "$1" in show) \(show) ;; *) \(TestSpot.toast) "Ran $1" ;; esac
        """)
    }

    private var log: URL {
        folder.appendingPathComponent("calls")
    }

    private var calls: [String] {
        ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    private func entry(_ id: String) throws -> SpotsModel.Entry {
        try XCTUnwrap(model.entries.first { $0.id == id })
    }

    private func learned(_ id: String) async throws {
        try await wait("the fact of \(id)") { self.model.runs.knownSheet(of: id) != nil }
    }

    func testASpotWithNoOnWhoseShowPrintsARowKeepsAHistoryAndOpensItsSheetOnReturn() async throws {
        try spot("dictate", toml: "title = 'Dictate'\n[commands.dictate]\ntitle = 'Dictate'", show: "printf 'text=one\\ntitle=Hello\\n'")
        await model.reload()
        XCTAssertFalse(try entry("dictate").spot.keepsHistory)

        try await learned("dictate")
        XCTAssertTrue(try entry("dictate").spot.keepsHistory)
        model.isShown = true
        model.panelWillShow()
        model.run(try entry("dictate"))

        try await wait("its rows") { self.model.openSheetID == "dictate" && self.titles == ["Hello"] }
        XCTAssertEqual(host.confirms, [])
    }

    func testASpotWithAnEventWhoseShowPrintsNothingRunsItsOneCommandOnReturn() async throws {
        try spot("wipe", toml: "title = 'Wipe'\non = ['panel.open']\n[commands.wipe]\ntitle = 'Wipe'", show: ":")
        await model.reload()
        XCTAssertTrue(try entry("wipe").spot.opensOnReturn)

        try await learned("wipe")
        XCTAssertFalse(try entry("wipe").spot.opensOnReturn)
        XCTAssertFalse(try entry("wipe").spot.keepsHistory)
        model.run(try entry("wipe"))

        try await wait("the command") { self.host.confirms == ["Ran wipe"] }
    }

    func testOpenspotRunOfASpotThatLearnedItsSheetShowsIt() async throws {
        try spot("notes", toml: "title = 'Notes'\n[commands.add]\ntitle = 'Add'", show: "printf 'text=one\\ntitle=Hello\\n'")
        await model.reload()
        try await learned("notes")

        let answer = try await XCTUnwrap(model.runs.api?.work(for: .test(["spot", "run", "notes"]), input: { "" }))()

        XCTAssertEqual(answer.output, "text=one\ntitle=Hello\n")
    }

    func testTheSpotsLoadAsksEachShowOnceAndAPressAsksNone() async throws {
        try spot("dictate", toml: "title = 'Dictate'\n[commands.dictate]\ntitle = 'Dictate'", show: ":")
        await model.reload()
        try await learned("dictate")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.query = "dictate"
        model.landSearch()
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "dictate" })

        XCTAssertEqual(model.hint, "⏎ Dictate   ⌘⏎ Settings   ⌘K Actions")
        model.runSelected()

        try await wait("the command") { self.host.confirms == ["Ran dictate"] }
        XCTAssertEqual(calls, ["show spot.want", "dictate "])
    }
}
