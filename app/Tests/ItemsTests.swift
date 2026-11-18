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

    private func open(_ frame: String, toml: String = "on = ['sheet.open']") async throws {
        let body = "#!/bin/sh\ncase \"$1\" in\nshow) sed -n 's/^search=/search /p' >> '\(log.path)'\ncat <<'EOF'\n\(frame)\nEOF\n;;\n*) echo \"$*\" >> '\(log.path)' ;;\nesac\n"
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

    func testATextThatTheGridDoesNotPlaceIsAnItemAndAButtonOrASectionKeepsItsRole() {
        let output = SpotOutput(text: """
        frame=
        grid=head

        text=head
        title=Photos

        text=beach
        title=Beach.jpg
        detail=Photo
        icon=photo

        button=delete
        title=Delete

        section=later
        title=Later

        switch=sync
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

    func testARowIsAnUnknownKind() {
        let output = SpotOutput(text: "row=a\ntitle=A\n\ntext=b\ntitle=B\n")

        XCTAssertEqual(output.items.map(\.run), ["b"])
        XCTAssertEqual(output.errors, ["row=a"])
    }

    func testWithNoGridTheSheetIsASearchFieldOverEachBlock() {
        let output = SpotOutput(text: "text=a\ntitle=A\n\nfield=name\ntitle=Name\n")
        let placed = SpotOutput(text: "frame=\ngrid=a\n\ntext=a\ntitle=A\n\ntext=b\ntitle=B\n")

        XCTAssertEqual(output.parts, [])
        XCTAssertEqual(output.items.map(\.run), ["a", "name"])
        XCTAssertEqual(output.search, .local)
        XCTAssertEqual(placed.items.map(\.run), ["b"])
        XCTAssertEqual(placed.search, .off)
    }

    func testASearchFieldFiltersInsideOpenspotAndWithFilterSpotTheSpotFilters() {
        let local = SpotOutput(text: "frame=\ngrid=find\ngrid=a\n\nfield=find\ntype=search\n\ntext=a\ntitle=A\n\ntext=b\ntitle=B\n")
        let spot = SpotOutput(text: "field=find\ntype=search\nfilter=spot\n\ntext=b\ntitle=B\n")

        XCTAssertEqual(local.search, .local)
        XCTAssertEqual(local.items.map(\.run), ["b"])
        XCTAssertEqual(local.layout?.rows, [["a"], [SpotOutput.itemsArea]])
        XCTAssertEqual(spot.search, .script)
        XCTAssertEqual(spot.items.map(\.run), ["b"])
        XCTAssertEqual(spot.parts, [])
    }

    func testAnItemIsSearchedAndPickedAsAMessage() async throws {
        try await open("text=apple\ntitle=Apple\nkind=fruit\n\ntext=milk\ntitle=Milk\n")

        model.searchText = "mil"
        try await wait("the search") { self.model.openItems?.shown.map(\.run) == ["milk"] }
        model.runSelectedItem()

        try await wait("the pick") { self.calls.contains("open milk") }
        XCTAssertEqual(host.dismissals, 1)
    }

    func testAPickWithCloseFalseKeepsThePanelOpen() async throws {
        try await open("text=star\ntitle=Star\nclose=false\n")
        let entry = try XCTUnwrap(model.openEntry)

        model.pick(try item("star"), of: entry)

        try await wait("the pick") { self.calls.contains("open star") }
        XCTAssertEqual(host.dismissals, 0)
        XCTAssertEqual(model.openSheetID, "items")
    }

    func testAnActClosesThePanelAndCloseFalseKeepsItOpen() async throws {
        try await open("button=star\ntitle=Star\nclose=false\n\nbutton=delete\ntitle=Delete\n\ntext=a\ntitle=A\n")
        let entry = try XCTUnwrap(model.openEntry)
        let actions = entry.spot.actions

        model.run(try XCTUnwrap(actions.first { $0.id == "star" }), on: (entry, try item("a")))
        try await wait("the star") { self.calls.contains("star a") }
        XCTAssertEqual(host.dismissals, 0)
        model.run(try XCTUnwrap(actions.first { $0.id == "delete" }), on: (entry, try item("a")))

        try await wait("the delete") { self.calls.contains("delete a") }
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

    func testASearchFieldWithFilterSpotSendsEachText() async throws {
        try await open("field=find\ntype=search\nfilter=spot\n\ntext=a\ntitle=A\n")

        model.searchText = "mi"

        try await wait("the text") { self.calls.contains("search mi") }
    }
}
