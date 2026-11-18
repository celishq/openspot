import XCTest
@testable import OpenspotCore

@MainActor
final class PlaygroundPlaceTests: XCTestCase {
    private var folder: URL!
    private var host: FakeHost!
    private var panel: PlaygroundPanel!

    override func setUp() async throws {
        try await super.setUp()
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("playground-\(UUID().uuidString)")
        host = FakeHost()
        panel = PlaygroundPanel(host: host, scratch: folder, defaults: UserDefaults(suiteName: "playground-\(UUID().uuidString)")!)
        host.model = panel.model
    }

    override func tearDown() async throws {
        panel.model.quit()
        try? FileManager.default.removeItem(at: folder)
        try await super.tearDown()
    }

    private let manifest = "title = \"Twice\"\non = [\"sheet.open\", \"clock.60\", \"search.text ^[0-9]\"]\n"
    private let answering = "#!/bin/sh\n. \"$OPENSPOT_SH\"\nvalue=$(value event.value)\nprintf 'text=t\\ntitle=%s\\n' \"$(value event)\"\n[ -n \"$value\" ] && printf '\\nrow=%s\\ntitle=Twice %s\\n' \"$value\" \"$value\"\n"

    func testATypedSpotLiesOnTheGridOfItsOwnPanel() async throws {
        let id = try await panel.place(file: nil, text: answering, manifest: manifest)

        XCTAssertEqual(id, "playground")
        XCTAssertEqual(panel.model.visible.map(\.id), ["playground"])
        XCTAssertEqual(panel.model.visible.map(\.spot.name), ["Twice"])
    }

    func testTheSheetOpensAndTheCardClosesIt() async throws {
        let id = try await panel.place(file: nil, text: answering, manifest: manifest)

        panel.show(.sheet, id: id)
        try await wait("the open sheet") { self.panel.model.openSheetID == id }
        panel.show(.card, id: id)

        try await wait("the closed sheet") { self.panel.model.openSheetID == nil }
    }

    func testTheMainSearchShowsTheRowsThatTheSpotAnswers() async throws {
        let id = try await panel.place(file: nil, text: answering, manifest: manifest)

        panel.show(.card, id: id)
        panel.model.searchText = "21"
        panel.model.landSearch()

        try await wait("the answer") { self.panel.model.visible.contains { $0.item?.title == "Twice 21" } }
    }

    func testANamedFileRunsFromACopyWithTheIdOfItsSpotsFolder() async throws {
        let spots = folder.appendingPathComponent("real-spots", isDirectory: true)
        let file = spots.spotFile("home/coffee")
        try "#!/bin/sh\n".writeScript(to: file)
        try "[scripts.coffee]\ntitle = \"Coffee\"\n".write(to: file.deletingLastPathComponent().appendingPathComponent("spot.toml"), atomically: true, encoding: .utf8)

        let id = try await panel.place(file: file, text: "#!/bin/sh\n", manifest: manifest, spots: spots)

        XCTAssertEqual(id, "home/coffee")
        XCTAssertEqual(panel.model.visible.map(\.id), ["home/coffee"])
        XCTAssertEqual(panel.model.visible.map(\.spot.name), ["Coffee"])
    }

    func testEachPlaceNamesTheLineThatTheSpotLacks() throws {
        let bare = Spot(id: "bare", name: "Bare", url: folder)
        let card = Spot(id: "card", name: "Card", url: folder, read: SpotRead(moments: [.panel]))

        XCTAssertNil(PlaygroundPlace.sheet.lack(of: bare))
        XCTAssertEqual(PlaygroundPlace.card.lack(of: bare), "The panel reads a card with panel.open or clock.<seconds> in its on.")
        XCTAssertNil(PlaygroundPlace.card.lack(of: card))
    }
}
