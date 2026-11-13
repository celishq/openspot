import XCTest
@testable import OpenspotCore

/// Proves the floats: a key with no command shows its spot in a window of its own, apart from the panel (W1–W9).
@MainActor
final class SpotFloatTests: XCTestCase {
    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: TestHost!
    private var model: SpotsModel!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-float-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        suite = "openspot-float-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        host = TestHost()
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path],
            home: folder,
            defaults: defaults
        )
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2))
        host.model = model
    }

    override func tearDown() async throws {
        model.quit()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: folder)
    }

    private var spots: URL {
        folder.appendingPathComponent("spots", isDirectory: true)
    }

    private func script(_ name: String, header: String, _ body: String) throws {
        let lines = header.split(separator: "\n").map { "# \($0)" }.joined(separator: "\n")
        try "#!/bin/sh\n\(lines)\n\(body)\n".writeScript(to: spots.spotFile(name))
    }

    private func wait(_ what: String, until condition: () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited for \(what)")
    }

    private func key(_ spot: String) throws -> GlobalKey {
        GlobalKey(spot: spot, act: .float, trigger: .key(try XCTUnwrap(Shortcut(text: "ctrl+option+s"))))
    }

    /// Floats a list of two rows whose pick and action each toast what they got.
    private func floatList() async throws {
        try script("list", header: "on=sheet.open", """
        case "$1" in
          read) printf 'row=a\\ntitle=%s\\n\\nrow=b\\ntitle=Banana\\n\\nbutton=trash\\ntitle=Trash\\nshortcut=cmd+backspace\\n\\nbutton=rename\\ntitle=Rename\\nform=true\\n' "$OPENSPOT_REASON" ;;
          open) printf 'toast=Opened %s\\n' "$2" ;;
          trash) printf 'toast=Trashed %s\\n' "$2" ;;
        esac
        """)
        model.reload()
        model.press(try key("list"))
        try await wait("the floating list") { model.sheets["list"]?.list.shown.count == 2 }
    }

    func testAKeyWithNoCommandFloatsItsSheetAndLeavesThePanel() async throws {
        try await floatList()

        XCTAssertEqual(host.floats, ["list"])
        XCTAssertEqual(host.shows, 0)
        XCTAssertNil(model.openList)
        XCTAssertEqual(model.runs.floating, ["list"])
        XCTAssertEqual(model.sheets["list"]?.list.shown.first?.title, "sheet.open")
    }

    func testTheSameKeyAgainClosesTheFloatAndDuringADragBringsItToThePointer() async throws {
        try await floatList()

        host.isMouseDown = true
        model.press(try key("list"))

        XCTAssertEqual(host.floats, ["list", "list"])
        XCTAssertEqual(model.runs.floating, ["list"])

        host.isMouseDown = false
        model.press(try key("list"))

        XCTAssertEqual(host.landings, ["list"])
        XCTAssertEqual(model.runs.floating, [])
    }

    func testTheKeysOfAFloatMoveThePickAndCloseIt() async throws {
        try await floatList()

        XCTAssertTrue(model.handleFloatKey(ActionKey(name: "down"), in: "list"))
        XCTAssertTrue(model.handleFloatKey(ActionKey(name: "return"), in: "list"))

        try await wait("the pick") { host.confirms == ["Opened b"] }
        XCTAssertEqual(model.runs.floating, ["list"])
        XCTAssertEqual(model.sheets["list"]?.list.selectedItem?.run, "b")

        XCTAssertTrue(model.handleFloatKey(ActionKey(name: "escape"), in: "list"))

        XCTAssertEqual(host.landings, ["list"])
        XCTAssertEqual(model.runs.floating, [])
        XCTAssertFalse(model.handleFloatKey(ActionKey(name: "k"), in: "list"))
    }

    func testTheShortcutOfAnActionRunsOnTheSelectedRowOfAFloat() async throws {
        try await floatList()

        XCTAssertTrue(model.handleFloatKey(ActionKey(name: "backspace", isCommand: true), in: "list"))

        try await wait("the action") { host.confirms == ["Trashed a"] }
        XCTAssertEqual(host.dismissals, 0)
    }

    func testAnActionThatAsksWithAFormOpensTheSpotInThePanel() async throws {
        try await floatList()
        let rename = try XCTUnwrap(model.sheets["list"]?.spot.actions.first { $0.id == "rename" })
        let entry = try XCTUnwrap(model.cards.first { $0.id == "list" })

        model.run(rename, on: (entry, model.sheets["list"]?.list.selectedItem), in: .float)

        XCTAssertEqual(host.shows, 1)
        try await wait("the sheet in the panel") { model.openList == "list" }
    }

    func testAFloatOfPartsKeepsItsValuesWhenThePanelClosesAndDropsThemWhenItCloses() async throws {
        try script("note", header: "on=sheet.open", "printf 'field=note\\nvalue=hi\\n'")
        model.reload()
        model.press(try key("note"))
        try await wait("the parts") { model.sheets["note"]?.panel != nil }

        model.panelWillShow(holding: [])
        model.runs.panelOpened()
        host.dismiss()

        XCTAssertNotNil(model.sheets["note"]?.panel)

        model.land("note")

        XCTAssertNil(model.sheets["note"]?.panel)
        XCTAssertEqual(host.landings, ["note"])
    }

    func testAFloatOfPartsWithNoFieldKeepsItsPartsWhenItCloses() async throws {
        try script("note", header: "on=sheet.open", "printf 'text=hi\\ntitle=Hi\\n'")
        model.reload()
        model.press(try key("note"))
        try await wait("the parts") { model.sheets["note"]?.panel != nil }

        model.land("note")

        XCTAssertNotNil(model.sheets["note"]?.panel)
        XCTAssertEqual(host.landings, ["note"])
    }

    func testADropOnAFloatGoesToItsScriptAndLeavesThePanel() async throws {
        try script("shelf", header: "on=sheet.open\ndrop=*", """
        case "$1" in
          read) printf 'row=a\\n' ;;
          drop) shift; printf 'toast=Kept %s\\n' "$*" ;;
        esac
        """)
        model.reload()
        model.press(try key("shelf"))
        try await wait("the float") { model.sheets["shelf"]?.list.shown.count == 1 }

        let files = ["a.png", "b.txt", "c.spot"].map { folder.appendingPathComponent($0).path }
        try files.forEach { try Data().write(to: URL(fileURLWithPath: $0)) }

        XCTAssertTrue(model.acceptsDrop([files[0]], on: "shelf", in: .float))
        XCTAssertFalse(model.acceptsDrop([files[2]], on: "shelf", in: .float))
        XCTAssertEqual(model.dropWords(Array(files.prefix(2)), on: "shelf"), "Add 2 files")
        XCTAssertTrue(model.drop(Array(files.prefix(2)), on: "shelf", in: .float))

        try await wait("the drop") { host.confirms == ["Kept \(files[0]) \(files[1])"] }
        XCTAssertEqual(host.shows, 0)
        XCTAssertNil(model.openList)
    }

    func testAShakeWhileARowThatTakesOneRecordsGivesItTheShake() async throws {
        let given = folder.appendingPathComponent("given").path
        try script("keys", header: "title=Keys\non=sheet.open", """
        case "$1" in
          read) printf 'button=open\\ntitle=Change\\nclose=false\\n\\nrow=panel_key\\ntitle=Open\\nshortcut=ctrl+space\\n\\nrow=float:shelf\\ntitle=Float\\nshortcut=Record\\nshake=true\\n' ;;
          *) printf '%s %s' "$1" "$2" > '\(given)' ;;
        esac
        """)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("config"), withIntermediateDirectories: true)
        try "[[spots]]\nid = \"keys\"\nkey = \"cmd+,\"\n".write(to: folder.appendingPathComponent("config/config.toml"), atomically: true, encoding: .utf8)
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.openSettings()
        try await wait("the rows of the keys") { model.openItems?.shown.contains { $0.run == "float:shelf" } == true }

        model.toggleRecording(id: "panel_key")
        XCTAssertEqual(model.recordingWords, "Press keys")
        model.recordShake()
        XCTAssertEqual(model.recording, "panel_key")

        model.toggleRecording(id: "float:shelf")
        XCTAssertEqual(model.recordingWords, "Press keys or shake")
        model.recordShake()

        XCTAssertNil(model.recording)
        try await wait("the shake given to the row") { (try? String(contentsOfFile: given, encoding: .utf8)) == "float:shelf shake" }
    }

    func testAFloatOfACardWithNoReadRunsNothingUntilItsCardIsPressed() async throws {
        try script("go", header: "title=Go", "printf 'toast=Went\\n'")
        model.reload()

        model.press(try key("go"))

        XCTAssertEqual(host.floats, ["go"])
        XCTAssertEqual(model.sheets["go"]?.isReading, false)
        XCTAssertEqual(model.sheets["go"]?.calls.isEmpty, true)

        model.pressFloatCard("go")

        try await wait("the run") { host.confirms == ["Went"] }
        XCTAssertEqual(host.dismissals, 0)
    }
}
