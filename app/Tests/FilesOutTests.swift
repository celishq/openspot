import XCTest
@testable import OpenspotCore

/// Proves the rows that a person drags out of a sheet as files (01, O1): `file` on a row, and the `drag` call after the drop.
@MainActor
final class FilesOutTests: XCTestCase {
    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: TestHost!
    private var model: SpotsModel!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-out-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        suite = "openspot-out-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        host = TestHost()
        let files = SpotFiles(
            environment: ["OPENSPOT_PLUGINS": plugins.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path],
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

    private var plugins: URL {
        folder.appendingPathComponent("plugins", isDirectory: true)
    }

    private func wait(_ what: String, until condition: () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited for \(what)")
    }

    func testARowCarriesTheFileThatItNamesFromTheRoot() {
        let output = SpotOutput(text: "row=a\nfile=/Users/me/a.png\n\nrow=b\nfile=b.png\n\nrow=c\n")

        XCTAssertEqual(output.items.map(\.file), ["/Users/me/a.png", nil, nil])
        XCTAssertTrue(output.partFaults.contains("the row b names the file b.png, which does not start with /"))
    }

    func testAComponentCannotTakeTheIdDragBesideRowsWithFiles() {
        let files = SpotOutput(text: "row=a\nfile=/a.png\n\nbutton=drag\ntitle=Drag\n\nfield=note\n")
        let none = SpotOutput(text: "row=a\n\nbutton=drag\ntitle=Drag\n\nfield=note\n")

        XCTAssertTrue(files.partFaults.contains("an action cannot be called drag"))
        XCTAssertFalse(none.partFaults.contains("an action cannot be called drag"))
    }

    func testTheDragCallNamesEachRow() {
        XCTAssertEqual(SpotAction.drag(runs: ["a", "b c"]).arguments, ["drag", "a", "b c"])
    }

    func testADragOutTellsTheScriptAndADragOfEveryFileClosesTheFloat() async throws {
        let body = """
        case "$1" in
          read) printf 'row=a\\nfile=/a.png\\n\\nrow=b\\nfile=/b.png\\n\\nrow=c\\n' ;;
          drag) shift; printf 'toast=Took %s\\n' "$*" ;;
        esac
        """
        try "#!/bin/sh\n# read=sheet\n\(body)\n".writeScript(to: plugins.appendingPathComponent("shelf.sh"))
        model.reload()
        model.press(GlobalKey(spot: "shelf", act: .float, trigger: .shake))
        try await wait("the rows") { model.sheets["shelf"]?.list.shown.count == 3 }
        let rows = try XCTUnwrap(model.sheets["shelf"]?.list.shown)

        model.dragOut([rows[0]], of: "shelf")

        try await wait("the drag") { host.confirms == ["Took a"] }
        XCTAssertEqual(host.landings, [])

        model.dragOut([rows[0], rows[1]], of: "shelf")

        XCTAssertEqual(host.landings, ["shelf"])
        try await wait("the drag of all") { host.confirms == ["Took a", "Took a b"] }
    }
}
