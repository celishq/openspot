import XCTest
@testable import OpenspotCore

final class SheetTreeInputsTests: PanelCase {
    private let form = """
    frame=\\nclass=gap-part\\n\\nfield=name\\ntitle=Name\\nvalue=Ada\\n\\n\
    box=foot\\nclass=flex-row gap-part\\n\\n\
    switch=wifi\\nparent=foot\\ntitle=Wi-Fi\\nvalue=true\\n\\n\
    choice=look\\nparent=foot\\nvalue=a\\n\\noption=a\\ntitle=A\\n\\noption=b\\ntitle=B\\n\\n\
    field=level\\nparent=foot\\ntype=slider\\nvalue=50\\n\\n\
    field=key\\ntype=hotkey\\nvalue=option+c\\n\\n\
    button=save\\ntitle=Save\\nclose=false\\n\\n\
    box=card\\nparent=save\\n\\ntext=words\\nparent=card\\ntitle=Save now\\n\\n\
    number=battery\\nvalue=84\\nmax=100\\n
    """

    private let list = """
    frame=\\nclass=gap-part\\n\\nfield=find\\ntype=search\\n\\nitems=list\\n\\n\
    text=a\\nparent=list\\ntitle=Apple\\nclose=false\\n\\ntext=b\\nparent=list\\ntitle=Banana\\n\\n\
    button=forget\\nparent=list\\ntitle=Forget\\nshortcut=cmd+f\\nclose=false\\n\\n\
    button=rename\\nparent=list\\ntitle=Rename\\n\\n\
    button=add\\ntitle=Add\\nclose=false\\n
    """

    private func open(_ sheet: String) async throws -> URL {
        let calls = folder.appendingPathComponent("calls")
        try script("tree", toml: "", "if [ \"$1\" = show ]; then printf '\(sheet)'; else echo \"$@\" >> '\(calls.path)'; fi")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.pushFirst("tree", moving: true)
        try await wait("the open sheet") { self.model.openSheetID == "tree" }
        return calls
    }

    private func calls(in file: URL) -> [String] {
        ((try? String(contentsOf: file, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    private func part(_ id: String) throws -> SpotPart {
        try XCTUnwrap(model.openParts?.parts.first { $0.id == id })
    }

    func testEachInputOfAWrittenTreeTakesTheKeysAndSendsItsValue() async throws {
        let calls = try await open(form)
        try await wait("the parts") { self.model.openParts != nil }

        XCTAssertEqual(model.openParts?.selectedPart?.id, "name")
        model.setPart(try part("name"), to: "Grace")
        try await wait("the text") { self.calls(in: calls).contains("name Grace") }

        XCTAssertTrue(model.handleKey(ActionKey(name: "down")))
        XCTAssertEqual(model.openParts?.selectedPart?.id, "wifi")
        XCTAssertTrue(model.handleKey(ActionKey(name: "return")))
        try await wait("the switch") { self.calls(in: calls).contains("wifi false") }

        XCTAssertTrue(model.handleKey(ActionKey(name: "right")))
        XCTAssertEqual(model.openParts?.selectedPart?.id, "look")
        XCTAssertTrue(model.handleKey(ActionKey(name: "return")))
        XCTAssertEqual(model.sheets["tree"]?.menuOpening?.part, "look")
        model.setPart(try part("look"), to: "b")
        try await wait("the choice") { self.calls(in: calls).contains("look b") }

        XCTAssertTrue(model.handleKey(ActionKey(name: "right")))
        XCTAssertEqual(model.openParts?.selectedPart?.id, "level")
        XCTAssertTrue(model.handleKey(ActionKey(name: "right")))
        try await wait("the slider") { self.calls(in: calls).contains("level 55") }

        XCTAssertTrue(model.handleKey(ActionKey(name: "down")))
        XCTAssertEqual(model.openParts?.selectedPart?.id, "key")
        XCTAssertTrue(model.handleKey(ActionKey(name: "return")))
        XCTAssertEqual(model.recording, "key")
        model.stopRecording()

        XCTAssertTrue(model.handleKey(ActionKey(name: "down")))
        XCTAssertEqual(model.openParts?.selectedPart?.id, "save")
        XCTAssertTrue(model.handleKey(ActionKey(name: "return")))
        try await wait("the press of the button that holds a card") { self.calls(in: calls).contains("save") }
        XCTAssertEqual(model.openParts?.focusOrder.map(\.id), ["name", "wifi", "look", "level", "key", "save"])
    }

    func testTheItemsOfAWrittenTreeRunTakeTheirActionsAndLeaveForThePartsBelow() async throws {
        let calls = try await open(list)
        try await wait("the items") { self.titles == ["Apple", "Banana"] }

        XCTAssertNil(model.openParts?.selectedPart)
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        XCTAssertEqual(model.menu?.rows.map(\.title).contains("Rename"), true)
        XCTAssertTrue(model.handleKey(escape))
        XCTAssertTrue(model.handleKey(ActionKey(name: "f", isCommand: true)))
        try await wait("the action on the item") { self.calls(in: calls).contains("forget a") }

        model.searchText = "app"
        model.landSearch()
        try await wait("the search") { self.titles == ["Apple"] }
        model.runSelectedItem()
        try await wait("the press of the item") { self.calls(in: calls).contains("open a") }
        model.searchText = ""
        model.landSearch()
        try await wait("all items") { self.titles == ["Apple", "Banana"] }

        for _ in 0..<2 where !model.handleKey(ActionKey(name: "down")) {
            XCTAssertTrue(model.handleSearchKey(ActionKey(name: "down")))
        }
        XCTAssertEqual(model.openParts?.selectedPart?.id, "add")
        XCTAssertTrue(model.handleKey(ActionKey(name: "return")))
        try await wait("the press of add") { self.calls(in: calls).contains("add") }
    }
}
