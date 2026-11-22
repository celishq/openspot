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
          press) echo "out.until=$(sed -n 's/^input.item=//p')" ;;
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

    func testThePushedViewTakesTheTitleOfItsRootAndARouteInItShowsItsPage() async throws {
        try script("days", toml: "title = 'Days'\npages = ['date']\n[actions.pick]\noutputs.until = 'text'", """
        in=$(cat)
        route=$(printf '%s\\n' "$in" | sed -n 's/^input.route=//p')
        case "$1:$route" in
          show:date) printf 'text=monday\\ntitle=Monday\\n' ;;
          show:*) printf 'text=s\\ntitle=Show\\n' ;;
          pick:*) printf 'frame=\\ntitle=For the tab\\n\\ntext=morning\\ntitle=Morning\\n\\ntext=pick\\ntitle=Pick Date\\nroute=date\\n' ;;
          press:*) echo "out.until=$(printf '%s\\n' "$in" | sed -n 's/^input.item=//p')" ;;
        esac
        """)
        try script("dater", toml: "title = 'Dater'\n[bindings]\ndays = { spot = 'days' }", """
        case "$1" in
          show) printf 'text=x\\ntitle=Dater\\n' ;;
          *) '\(client.path)' run days.pick --out until > '\(path("out"))' 2> '\(path("errors"))'; echo $? >> '\(path("done"))' ;;
        esac
        """)
        await model.reload()
        try XCTUnwrap(model.sheets["dater"]).pressCard()
        try await wait("the pushed view") { self.model.transition.phase == .open && self.titles == ["Morning", "Pick Date"] }

        XCTAssertEqual(model.flow.current?.title, "For the tab")
        model.sheets["days"]?.list.select(run: "pick")
        model.runSelectedItem()

        try await wait("the page of the route") { self.titles == ["Monday"] }
        model.sheets["days"]?.list.select(run: "monday")
        model.runSelectedItem()
        try await wait("the end of the run") { self.log("done").count == 1 }
        XCTAssertEqual(log("out"), ["monday"])
    }

    private func runPickInAWindow() async throws -> SpotRun {
        _ = try model.files.config.change { $0.arrangement.set(isWindow: true, of: "picker") }
        await model.reload()
        let picker = try XCTUnwrap(model.sheets["picker"])
        try XCTUnwrap(model.sheets["asker"]).pressCard()
        try await wait("the view in the window") { self.host.windows == ["picker"] && picker.list.all.map(\.title) == ["Morning", "Evening"] }
        return picker
    }

    func testAPushedViewOfASpotPlacedInAWindowOpensTheWindowAndClosesItWhenAPressInItGivesValues() async throws {
        let picker = try await runPickInAWindow()

        picker.pick(try XCTUnwrap(picker.list.all.first { $0.run == "evening" }))

        try await wait("the end of the run") { self.log("done").count == 1 }
        XCTAssertEqual(log("done"), ["0"], log("errors").joined(separator: "\n"))
        XCTAssertEqual(log("out"), ["evening"])
        try await wait("the window closed") { !self.model.runs.floating.contains("picker") }
    }

    func testClosingTheWindowOfAPushedViewCancelsTheRunWithExit4() async throws {
        _ = try await runPickInAWindow()

        model.land("picker")

        try await wait("the end of the run") { self.log("done").count == 1 }
        XCTAssertEqual(log("done"), ["4"])
        XCTAssertEqual(log("out"), [])
    }
}
