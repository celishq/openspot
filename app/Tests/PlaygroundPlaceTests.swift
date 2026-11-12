import XCTest
@testable import OpenspotCore

/// Proves the playground's panel: it runs one spot in a real panel model over a folder of its own, keeps it on the grid,
/// and shows it in the place that the person picks: its sheet, its card, or the main search.
@MainActor
final class PlaygroundPlaceTests: XCTestCase {
    private var folder: URL!
    private var host: TestHost!
    private var panel: PlaygroundPanel!

    override func setUp() async throws {
        try await super.setUp()
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("playground-\(UUID().uuidString)")
        host = TestHost()
        panel = PlaygroundPanel(host: host, scratch: folder, defaults: UserDefaults(suiteName: "playground-\(UUID().uuidString)")!)
        host.model = panel.model
    }

    override func tearDown() async throws {
        panel.model.quit()
        try? FileManager.default.removeItem(at: folder)
        try await super.tearDown()
    }

    private func wait(_ what: String, until condition: @escaping () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited for \(what)")
    }

    private let answering = "#!/bin/sh\n# title=Twice\n# on=sheet.open\n# on=clock.60\n# on=search.text ^[0-9]\nprintf 'text=t\\ntitle=%s\\n' \"$OPENSPOT_REASON\"\n[ -n \"$OPENSPOT_VALUE\" ] && printf '\\nrow=%s\\ntitle=Twice %s\\n' \"$OPENSPOT_VALUE\" \"$OPENSPOT_VALUE\"\n"

    func testATypedSpotLiesOnTheGridOfItsOwnPanel() throws {
        let id = try panel.place(file: nil, text: answering)

        XCTAssertEqual(id, "playground")
        XCTAssertEqual(panel.model.visible.map(\.id), ["playground"])
    }

    func testTheSheetOpensAndTheCardClosesIt() async throws {
        let id = try panel.place(file: nil, text: answering)

        panel.show(.sheet, id: id)
        try await wait("the open sheet") { self.panel.model.openList == id }
        panel.show(.card, id: id)

        try await wait("the closed sheet") { self.panel.model.openList == nil }
    }

    func testTheMainSearchShowsTheRowsThatTheSpotAnswers() async throws {
        let id = try panel.place(file: nil, text: answering)

        panel.show(.search, id: id)
        panel.model.searchText = "21"

        try await wait("the answer") { self.panel.model.visible.contains { $0.item?.title == "Twice 21" } }
    }

    func testANamedFileRunsFromACopyWithTheIdOfItsPluginsFolder() throws {
        let plugins = folder.appendingPathComponent("real-plugins/home", isDirectory: true)
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        let file = plugins.appendingPathComponent("coffee.sh")
        try "#!/bin/sh\n# title=Coffee\n".writeScript(to: file)

        let id = try panel.place(file: file, text: "#!/bin/sh\n# title=Coffee\n", plugins: plugins.deletingLastPathComponent())

        XCTAssertEqual(id, "home/coffee")
        XCTAssertEqual(panel.model.visible.map(\.id), ["home/coffee"])
    }

    func testEachPlaceNamesTheLineThatTheSpotLacks() throws {
        let bare = Spot(id: "bare", name: "Bare", url: folder)
        let card = Spot(id: "card", name: "Card", url: folder, read: SpotRead(moments: [.panel]))
        let answer = Spot(id: "answer", name: "Answer", url: folder, answers: AnswerPattern("^[0-9]"))

        XCTAssertNil(PlaygroundPlace.sheet.lack(of: bare))
        XCTAssertEqual(PlaygroundPlace.card.lack(of: bare), "The panel reads a card with on=panel.open or on=clock.<seconds>.")
        XCTAssertNil(PlaygroundPlace.card.lack(of: card))
        XCTAssertEqual(PlaygroundPlace.search.lack(of: card), "The main search asks a spot with on=search.text <pattern>, such as on=search.text ^[0-9].")
        XCTAssertNil(PlaygroundPlace.search.lack(of: answer))
    }
}
