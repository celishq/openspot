import XCTest
@testable import OpenspotCore

@MainActor
final class ItemsTests: PanelCase {
    private var log: URL {
        folder.appendingPathComponent("log")
    }

    private var calls: [String] {
        ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    private func open(_ frame: String, toml: String = "") async throws {
        let body = "#!/bin/sh\ncase \"$1\" in\nshow) cat <<'EOF'\n\(frame)\nEOF\n;;\n*) v=$(sed -n -e 's/^input\\.item=//p' -e 's/^input\\.value=//p' | head -n 1); echo \"$1${v:+ $v}\" >> '\(log.path)' ;;\nesac\n"
        try body.writeScript(to: spots.spotFile("items"), toml: toml)
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("items")
        try await wait("the items") { self.model.openSheetID == "items" && self.model.openItems?.shown.isEmpty == false }
    }

    private func item(_ run: String) throws -> SpotItem {
        try XCTUnwrap(model.openItems?.shown.first { $0.run == run })
    }

    func testABlockInsideTheItemsIsAnItemAndAButtonOrASectionTitleKeepsItsRole() {
        let output = Frame(text: """
        frame=
        class=gap-part

        text=head
        title=Photos

        items=list

        item=beach
        parent=list
        title=Beach.jpg
        detail=Photo
        icon=photo

        button=delete
        parent=list
        title=Delete

        box=later
        parent=list
        title=Later

        switch=sync
        parent=later
        title=Sync
        value=true
        """)

        XCTAssertEqual(output.parts.map(\.id), ["head"])
        XCTAssertEqual(output.items.map(\.run), ["beach", "sync"])
        XCTAssertEqual(output.items.first, SpotItem(title: "Beach.jpg", subtitle: "Photo", run: "beach", picture: .symbol("photo")))
        XCTAssertEqual(output.items.map(\.section), [nil, "Later"])
        XCTAssertEqual(output.actions.map(\.id), ["delete"])
        XCTAssertEqual(output.errors, [])
    }

    func testABlockThatOnlyTheBarShowsStaysOutOfTheSheet() {
        let output = Frame(text: """
        frame=
        class=gap-part

        number=count
        value=5
        title=Pull requests
        class=hidden bar:flex

        items=items

        item=a
        parent=items
        title=A
        """)

        XCTAssertEqual(output.tree.shown(in: [.sheet]), ["items", "a"])
        XCTAssertEqual(output.items.map(\.run), ["a"])
        XCTAssertEqual(output.barred.metric?.value("value"), "5")
    }

    func testAChoiceIsNeverAnItemSoTheSheetDrawsItsPicker() {
        let output = Frame(text: """
        frame=
        title=Look

        choice=look
        title=Look
        value=colorful

        option=colorful
        title=Colorful

        option=plain
        title=Plain
        """)

        XCTAssertEqual(output.items, [])
        XCTAssertEqual(output.parts.map(\.id), ["look"])
        XCTAssertEqual(output.parts.first?.control, .menu([.init(id: "colorful", title: "Colorful"), .init(id: "plain", title: "Plain")], value: "colorful"))
    }

    func testASheetOfThreeLinesOfTilesFitsItsLines() async throws {
        let tiles = (1...9).map { "item=t\($0)\nparent=tiles\ntitle=T\($0)\ndetail=D\nicon=star\nclass=bg-tile\n" }.joined(separator: "\n")
        try await open("frame=\nclass=gap-part\n\nitems=tiles\nclass=grid grid-cols-3\n\n\(tiles)")

        let sheet = try XCTUnwrap(model.sheets["items"]).sheetRect
        let lines = 3 * SpotTokens.square(perLine: 3) + 2 * SpotTokens.listRowGap
        XCTAssertLessThan(sheet.height, SpotTokens.sheetMaxHeight)
        XCTAssertGreaterThanOrEqual(sheet.height, lines)
    }

    func testASheetOfItemsHoldsALineForItsSectionTitle() async throws {
        try await open("items=devices\n\nbox=nearby\nparent=devices\ntitle=Nearby\n\nitem=mouse\nparent=nearby\ntitle=Mouse\n\nitem=keyboard\nparent=nearby\ntitle=Keyboard\n")

        let sheet = try XCTUnwrap(model.sheets["items"])
        XCTAssertEqual(sheet.sheetRect, SpotTokens.sheetRect(rows: 3, top: sheet.top))
    }

    func testATextItemsNumberIsNoMarkAndANumberItemWithAMaxFills() {
        let output = Frame(text: "item=mac\ntitle=This Mac\ndetail=84%\nvalue=0.84\n\nnumber=swap\ntitle=Swap\nvalue=84\nmax=100\n")

        XCTAssertNil(output.items.first?.number)
        XCTAssertEqual(output.items.last?.number?.fill, 0.84)
    }

    func testARowIsAnUnknownKind() {
        let output = Frame(text: "row=a\ntitle=A\n\nitem=b\ntitle=B\n")

        XCTAssertEqual(output.items.map(\.run), ["b"])
        XCTAssertEqual(output.errors, ["row=a"])
    }

    func testWithNoTreeTheSheetIsASearchFieldOverEachBlock() {
        let output = Frame(text: "item=a\ntitle=A\n\nfield=name\ntitle=Name\n")
        let placed = Frame(text: "frame=\nclass=gap-part\n\ntext=a\ntitle=A\n\nitems=list\n\nitem=b\nparent=list\ntitle=B\n")

        XCTAssertEqual(output.parts, [])
        XCTAssertEqual(output.items.map(\.run), ["a", "name"])
        XCTAssertEqual(output.search, .local)
        XCTAssertEqual(placed.items.map(\.run), ["b"])
        XCTAssertEqual(placed.search, .off)
    }

    func testASearchFieldFiltersInsideOpenspot() {
        let local = Frame(text: "frame=\nclass=gap-part\n\nfield=find\ntype=search\n\ntext=a\ntitle=A\n\nitems=list\n\nitem=b\nparent=list\ntitle=B\n")

        XCTAssertEqual(local.search, .local)
        XCTAssertEqual(local.items.map(\.run), ["b"])
        XCTAssertEqual(local.parts.map(\.id), ["a"])
    }

    func testFilterOnASearchFieldIsAnUnknownKey() {
        let text = "field=find\ntype=search\nfilter=spot\n\nitem=b\ntitle=B\n"

        XCTAssertEqual(Frame(text: text).search, .local)
        XCTAssertEqual(FrameCheck(text: text).partFaults, ["the part find has an unknown key: filter"])
    }

    func testAnItemRowTakesItsKeysAndItsPressSendsPress() async throws {
        try await open("item=star\ntitle=Star\ndetail=A star\nicon=star\ntone=good\nopen.title=Show\nclose=false\nhides=reveal\n")
        let entry = try XCTUnwrap(model.openEntry)
        let star = try item("star")

        XCTAssertEqual(star, SpotItem(title: "Star", subtitle: "A star", run: "star", picture: .symbol("star"), hides: ["reveal"], tone: .good, openTitle: "Show", staysOnPick: true))
        model.pick(star, of: entry)

        try await wait("the pick") { self.calls.contains("press star") }
        XCTAssertEqual(host.dismissals, 0)
    }

    func testAnItemRowTakesARoute() {
        let output = Frame(text: "item=day\ntitle=Monday\nroute=monday\nroute.title=On Monday\n")

        XCTAssertEqual(output.items.first?.move, .push(spot: nil, route: "monday", title: "On Monday", replace: false))
    }

    func testAnItemIsSearchedAndPickedAsAMessage() async throws {
        try await open("item=apple\ntitle=Apple\nkind=fruit\n\nitem=milk\ntitle=Milk\n")

        model.search("mil")
        try await wait("the search") { self.model.openItems?.shown.map(\.run) == ["milk"] }
        model.runSelectedItem()

        try await wait("the pick") { self.calls.contains("press milk") }
        try await wait("the close") { self.host.dismissals == 1 }
    }

    func testAPickKeepsThePanelOpenUntilItsCallEndsWithNoView() async throws {
        let gate = folder.appendingPathComponent("gate").path
        let started = folder.appendingPathComponent("started").path
        try script("slow", toml: "title = 'Slow'", """
        case "$1" in
          show) printf 'item=milk\\ntitle=Milk\\n' ;;
          press) touch '\(started)'; n=0; while [ ! -f '\(gate)' ] && [ $n -lt 1500 ]; do sleep 0.02; n=$((n + 1)); done ;;
        esac
        """)
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("slow")
        try await wait("the row") { self.model.openItems?.shown.map(\.run) == ["milk"] }

        model.runSelectedItem()
        try await wait("the press") { FileManager.default.fileExists(atPath: started) }
        XCTAssertEqual(host.dismissals, 0)
        FileManager.default.createFile(atPath: gate, contents: Data())

        try await wait("the close") { self.host.dismissals == 1 }
    }

    func testAPickWithCloseFalseKeepsThePanelOpen() async throws {
        try await open("item=star\ntitle=Star\nclose=false\n")
        let entry = try XCTUnwrap(model.openEntry)

        model.pick(try item("star"), of: entry)

        try await wait("the pick") { self.calls.contains("press star") }
        XCTAssertEqual(host.dismissals, 0)
        XCTAssertEqual(model.openSheetID, "items")
    }

    func testAnActClosesThePanelAndCloseFalseKeepsItOpen() async throws {
        try await open("button=star\ntitle=Star\nclose=false\n\nbutton=delete\ntitle=Delete\n\nitem=a\ntitle=A\n")
        let entry = try XCTUnwrap(model.openEntry)
        let actions = entry.spot.frameActions

        let sheet = try XCTUnwrap(model.runs.sheets["items"])
        model.run(try XCTUnwrap(actions.first { $0.id == "star" }), on: (entry, try item("a")))
        try await wait("the end of the star") { self.calls.contains("star a") && sheet.calls.isEmpty }
        XCTAssertEqual(host.dismissals, 0)
        model.run(try XCTUnwrap(actions.first { $0.id == "delete" }), on: (entry, try item("a")))

        try await wait("the close after the delete") { self.calls.contains("delete a") && self.host.dismissals > 0 }
        XCTAssertEqual(host.dismissals, 1)
    }

    func testASwitchItemSendsItsIDAndItsNextValue() async throws {
        try await open("switch=sync\ntitle=Sync\nvalue=true\nclose=false\n\nswitch=wifi\ntitle=Wi-Fi\nclose=false\n")
        let entry = try XCTUnwrap(model.openEntry)

        XCTAssertTrue(try item("sync").isToggle)
        XCTAssertTrue(try item("sync").isOn)
        model.pick(try item("sync"), of: entry)
        model.pick(try item("wifi"), of: entry)

        try await wait("both switches") { self.calls.contains("sync false") && self.calls.contains("wifi true") }
    }

    func testAHotkeyFieldItemRecordsAKeyIntoItsValue() async throws {
        try await open("field=key\ntype=hotkey\ntitle=Open\nshake=true\nclose=false\n")

        XCTAssertTrue(try item("key").records)
        XCTAssertTrue(try item("key").takesShake)
        XCTAssertEqual(try item("key").shortcut, Trigger.unset)
        model.toggleRecording(id: "key")
        model.record(code: 0, modifiers: [.control, .option])

        try await wait("the key") { self.calls.contains("key ctrl+option+a") }
        XCTAssertEqual(host.dismissals, 0)
    }
}
