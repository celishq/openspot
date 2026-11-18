import XCTest
@testable import OpenspotCore

@MainActor
final class FilesOutTests: XCTestCase {
    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: FakeHost!
    private var model: SpotsModel!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-out-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        suite = "openspot-out-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        host = FakeHost()
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

    func testARowCarriesTheFileThatItNamesFromTheRoot() {
        let outputCheck = FrameCheck(text: "row=a\nfile=/Users/me/a.png\n\nrow=b\nfile=b.png\n\nrow=c\n")
        let output = outputCheck.output

        XCTAssertEqual(output.items.map(\.file), ["/Users/me/a.png", nil, nil])
        XCTAssertTrue(outputCheck.partFaults.contains("the row b names the file b.png, which does not start with /"))
    }

    func testAComponentCannotTakeTheIdDragBesideRowsWithFiles() {
        let filesCheck = FrameCheck(text: "row=a\nfile=/a.png\n\nbutton=drag\ntitle=Drag\n\nfield=note\n")
        let noneCheck = FrameCheck(text: "row=a\n\nbutton=drag\ntitle=Drag\n\nfield=note\n")

        XCTAssertTrue(filesCheck.partFaults.contains("an action cannot be called drag"))
        XCTAssertFalse(noneCheck.partFaults.contains("an action cannot be called drag"))
    }

    func testTheDragCallNamesEachRow() {
        XCTAssertEqual(SpotAction.drag(runs: ["a", "b c"]).arguments, ["drag", "a", "b c"])
    }

    func testADragOutTellsTheScriptAndADragOfEveryFileClosesTheFloat() async throws {
        let body = """
        case "$1" in
          show) printf 'row=a\\nfile=/a.png\\n\\nrow=b\\nfile=/b.png\\n\\nrow=c\\n' ;;
          drag) shift; printf '\\033]9;Took %s\\007' "$*" ;;
        esac
        """
        try "#!/bin/sh\n\(body)\n".writeScript(to: spots.spotFile("shelf"), toml: "on = ['sheet.open']")
        await model.reload()
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
