import XCTest
@testable import OpenspotCore

@MainActor
final class SpotEffectTests: PanelCase {
    private var client: URL!

    override var stopPause: TimeInterval {
        5
    }

    override func setUp() async throws {
        try await super.setUp()
        client = folder.appendingPathComponent("A.app/Contents/Helpers/openspot")
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: client)
        model.runs.api = CommandAPI(mac: Mac(), places: model.files, app: ModelApp(model: model), runs: model.runs)
    }

    private func path(_ name: String) -> String {
        folder.appendingPathComponent(name).path
    }

    private func log(_ name: String) -> [String] {
        ((try? String(contentsOfFile: path(name), encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    private func writeFlow(show: String = "") throws {
        let buttons = ["next", "root", "back", "close", "saved", "pick", "late", "other"].map { "button=\($0)\\ntitle=\($0)\\nscope=spot\\n\\n" }.joined()
        try script("flow", toml: "title = 'Flow'\npages = ['*']", """
        os='\(client.path)'
        codes='\(path("codes"))'
        in=$(cat)
        route=$(printf '%s\\n' "$in" | sed -n 's/^input\\.route=//p')
        case "$1" in
          show) echo "${route:-first}" >> '\(path("routes"))'; \(show) printf '\(buttons)item=a\\ntitle=Page %s\\n\\nitem=b\\ntitle=B\\n\\nitem=c\\ntitle=C\\n' "${route:-first}" ;;
          next) "$os" route push "n${#route}" --title "Next page" ;;
          root) "$os" route back --root ;;
          back) "$os" route back ;;
          close) "$os" route close ;;
          saved) "$os" toast Saved ;;
          pick) "$os" select c ;;
          late) trap '"$os" toast Late; echo "late $?" >> "$codes"; exit 0' TERM; echo up >> "$codes"; sleep 30 & wait ;;
        esac
        echo "$1 $?" >> "$codes"
        """)
    }

    private func openFlow(show: String = "") async throws {
        try writeFlow(show: show)
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("flow")
        try await wait("the flow") { self.model.transition.phase == .open && self.titles.first == "Page first" && self.model.sheets["flow"]?.spot.frameActions.count == 8 }
    }

    private func press(_ id: String, in spot: String = "flow") throws {
        let sheet = try XCTUnwrap(model.sheets[spot])
        sheet.run(try XCTUnwrap(sheet.spot.frameActions.first { $0.id == id }), item: nil)
    }

    private func pressed(_ id: String) async throws -> String? {
        let count = log("codes").count { $0.hasPrefix("\(id) ") }
        try press(id)
        try await wait("the end of \(id)") { self.log("codes").count { $0.hasPrefix("\(id) ") } == count + 1 }
        return log("codes").last { $0.hasPrefix("\(id) ") }
    }

    private func call(_ words: [String]) async throws -> CommandAnswer {
        let api = try XCTUnwrap(model.runs.api)
        let work = try XCTUnwrap(api.work(for: .test(words), input: { "" }))
        return await work()
    }

    func testAToastFromAPressShows() async throws {
        try await openFlow()

        let code = try await pressed("saved")

        XCTAssertEqual(code, "saved 0")
        XCTAssertEqual(host.confirms, ["Saved"])
    }

    func testAToastFromAReadShowsToo() async throws {
        try await openFlow(show: "\"$os\" toast Read;")

        try await wait("the toast") { self.host.confirms == ["Read"] }
    }

    func testARoutePushFromAPressPushesTheRouteAndTheNextMessageCarriesIt() async throws {
        try await openFlow()

        let code = try await pressed("next")

        XCTAssertEqual(code, "next 0")
        try await wait("the pushed page") { self.titles.first == "Page n0" }
        XCTAssertEqual(model.flow.current, FlowSheet(spot: "flow", route: "n0", title: "Next page"))
        XCTAssertEqual(log("routes").last, "n0")
    }

    func testRouteBackRootAndCloseMoveTheFlowAsPopAllAndEscDo() async throws {
        try writeFlow()
        try await openList()
        XCTAssertTrue(model.push(FlowSheet(spot: "flow")))
        try await wait("the flow over the list") { self.model.openSheetID == "flow" && self.titles.first == "Page first" }
        _ = try await pressed("next")
        try await wait("the first page") { self.titles.first == "Page n0" }
        _ = try await pressed("next")
        try await wait("the second page") { self.titles.first == "Page n2" }

        _ = try await pressed("back")
        try await wait("one page back") { self.titles.first == "Page n0" && self.model.flow.current?.route == "n0" }
        _ = try await pressed("next")
        try await wait("the second page again") { self.titles.first == "Page n2" }
        _ = try await pressed("root")
        try await wait("the first sheet of the spot") { self.titles.first == "Page first" && self.model.flow.current == FlowSheet(spot: "flow") }
        _ = try await pressed("next")
        try await wait("a page again") { self.titles.first == "Page n0" }
        _ = try await pressed("close")

        try await wait("the list that pushed the spot") { self.model.openSheetID == "list" && self.titles == ["A"] }
        XCTAssertNil(model.flow.ahead)
    }

    func testRouteCloseOnASpotWithNothingBehindGoesToTheGrid() async throws {
        try await openFlow()

        _ = try await pressed("close")

        try await wait("the grid") { self.model.openSheetID == nil }
    }

    func testASpotCannotMoveARouteOfAnotherSpot() async throws {
        try await openList()
        try await openPage()
        try script("mover", toml: "title = 'Mover'", """
        [ "$1" = press ] || exit 0
        '\(client.path)' route back; echo "go $?" >> '\(path("codes"))'
        '\(client.path)' route push x; echo "go $?" >> '\(path("codes"))'
        """)
        await model.reload()
        let mover = try XCTUnwrap(model.sheets["mover"])

        mover.pressCard()

        try await wait("both moves") { self.log("codes").count == 2 }
        XCTAssertEqual(log("codes"), ["go 0", "go 0"])
        XCTAssertEqual(model.flow.current, FlowSheet(spot: "list", route: "a", title: "A"))
        XCTAssertEqual(titles, ["Detail a"])
    }

    func testARouteMoveFailsInAReadAndMovesNothing() async throws {
        try await openFlow(show: "[ -z \"$route\" ] && { \"$os\" route push elsewhere 2> '\(path("errors"))'; echo \"read $?\" >> \"$codes\"; };")

        try await wait("the read") { self.log("codes").contains("read 1") }

        XCTAssertTrue(log("errors").joined().contains("cannot run in a show"), log("errors").joined())
        XCTAssertEqual(model.flow.pages, [FlowSheet(spot: "flow")])
    }

    func testSelectSelectsTheItemAfterTheNextFrame() async throws {
        try await openFlow()
        let sheet = try XCTUnwrap(model.sheets["flow"])
        XCTAssertEqual(sheet.list.selectedItem?.run, "a")

        let code = try await pressed("pick")

        XCTAssertEqual(code, "pick 0")
        try await wait("c selected") { sheet.list.selectedItem?.run == "c" }
    }

    func testACommandOfACallThatWasStoppedDoesNothingAndExitsZero() async throws {
        try await openFlow()
        let sheet = try XCTUnwrap(model.sheets["flow"])
        try press("late")
        try await wait("the call to wait") { self.log("codes").contains("up") }
        let call = try XCTUnwrap(sheet.calls.first { $0.handler == "late" })

        sheet.stop(call)

        try await wait("the late toast to end") { self.log("codes").contains("late 0") }
        XCTAssertEqual(host.confirms, [])
    }

    func testThePersonsToastAndRouteActOnTheSheetThatShows() async throws {
        try await openFlow()
        _ = try await pressed("next")
        try await wait("the pushed page") { self.titles.first == "Page n0" }

        let toast = try await call(["toast", "Hello", "there"])
        let back = try await call(["route", "back"])

        XCTAssertEqual(toast.code, 0)
        XCTAssertEqual(back.code, 0)
        XCTAssertEqual(host.confirms, ["Hello there"])
        try await wait("the first sheet") { self.titles.first == "Page first" }
    }

    func testThePersonsRouteMoveFailsWhenNoSheetShows() async throws {
        try await openFlow()
        model.closeSheet(moving: false)
        try await wait("the grid") { self.model.openSheetID == nil }

        let back = try await call(["route", "back"])

        XCTAssertEqual(back.code, 1)
        XCTAssertEqual(back.errors, "The panel shows no sheet. Open a spot, then run `openspot route back` again.\n")
    }
}
