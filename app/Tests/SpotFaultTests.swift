import XCTest
@testable import OpenspotCore

/// Proves that the panel keeps each fault of a spot where the person looks: a file that does not load keeps a card, a failed
/// run marks its card, and a change of the plugins folder shows at once.
@MainActor
final class SpotFaultTests: XCTestCase {
    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: TestHost!
    private var model: SpotsModel!
    private let path = ProcessInfo.processInfo.environment["PATH"]

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-fault-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        let tools = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        for (name, body) in [("pbcopy", "cat > '\(folder.path)/clipboard'"), ("open", "echo \"$@\" > '\(folder.path)/opened'")] {
            try "#!/bin/sh\n\(body)\n".writeScript(to: tools.appendingPathComponent(name))
        }
        setenv("PATH", "\(tools.path):/usr/bin:/bin", 1)
        suite = "openspot-fault-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        host = TestHost()
        host.shipped = ShippedSpot.commands(folder: plugins, guide: folder.appendingPathComponent("GUIDE.md"), app: "/Apps/Openspot")
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
        if let path { setenv("PATH", path, 1) }
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: folder)
    }

    private var plugins: URL {
        folder.appendingPathComponent("plugins", isDirectory: true)
    }

    private func script(_ name: String, header: String = "", _ body: String) throws {
        let lines = header.split(separator: "\n").map { "# \($0)" }.joined(separator: "\n")
        try "#!/bin/sh\n\(lines)\n\(body)\n".writeScript(to: plugins.appendingPathComponent("\(name).sh"))
    }

    private func wait(_ what: String, until condition: () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited for \(what)")
    }

    private func entry(_ id: String) -> SpotsModel.Entry? {
        model.entries.first { $0.id == id }
    }

    private func saved(_ name: String) -> String? {
        try? String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
    }

    /// Opens the sheet of the spot of a file that does not load.
    private func openFault() async throws -> SheetParts {
        try script("weather", header: "size=huge", "echo")
        model.reload()
        model.isShown = true
        model.press("weather")
        try await wait("the fault sheet") { model.openPanel != nil }
        return try XCTUnwrap(model.openPanel)
    }

    func testAFileThatDoesNotLoadKeepsAWideCardThatSaysHowToFixIt() throws {
        try script("weather", header: "size=huge", "echo")

        model.reload()

        let card = try XCTUnwrap(entry("weather"))
        XCTAssertEqual(card.state.title, "Fix")
        XCTAssertEqual(card.state.subtitle, "Weather")
        XCTAssertEqual(card.size, .wide)
        XCTAssertTrue(card.isOnGrid)
        XCTAssertEqual(host.notes, [])
    }

    func testAFaultCardStaysWideWhenThePersonChoseTheSmallSize() throws {
        try script("weather", header: "size=huge", "echo")
        model.reload()

        model.prefer(.small, for: "weather")

        XCTAssertEqual(entry("weather")?.size, .wide)
    }

    func testTheFaultSheetShowsTheFileAndEachFaultWithItsFixes() async throws {
        let sheet = try await openFault()

        let text = sheet.parts.compactMap { if case .text(let value, _, _) = $0.control { value } else { nil } }.joined()
        XCTAssertTrue(text.contains(plugins.appendingPathComponent("weather.sh").path))
        XCTAssertTrue(text.contains("Weather has an unknown size: huge"))
        XCTAssertEqual(Set(sheet.parts.map(\.id)).intersection(["fix", "edit"]), ["fix", "edit"])
    }

    func testCopyPromptForAICopiesAPromptThatNamesTheFileTheFaultAndTheCheck() async throws {
        let sheet = try await openFault()
        let fix = try XCTUnwrap(sheet.parts.first { $0.id == "fix" })
        XCTAssertEqual(fix.title, "Copy prompt for AI")

        model.pressPart(fix)
        try await wait("the whole prompt") { saved("clipboard")?.contains("what the spot runs on my computer.") == true }

        let prompt = try XCTUnwrap(saved("clipboard"))
        XCTAssertTrue(prompt.contains(plugins.appendingPathComponent("weather.sh").path))
        XCTAssertTrue(prompt.contains("Weather has an unknown size: huge"))
        XCTAssertTrue(prompt.contains("check"))
    }

    func testEditOpensTheFileInTheTextEditor() async throws {
        let sheet = try await openFault()

        model.pressPart(try XCTUnwrap(sheet.parts.first { $0.id == "edit" }))
        try await wait("the editor") { saved("opened")?.hasSuffix("\n") == true }

        XCTAssertEqual(saved("opened"), "-t \(plugins.appendingPathComponent("weather.sh").path)\n")
    }

    func testAFileThatLoadsAgainTakesBackItsCard() throws {
        try script("weather", header: "size=huge", "echo")
        model.reload()

        try script("weather", header: "size=small", "echo")
        model.folderChanged()

        XCTAssertEqual(entry("weather")?.state.title, "Weather")
        XCTAssertNil(entry("weather")?.command.fault)
    }

    func testAFailedRunMarksItsCardUntilARunSucceeds() async throws {
        try script("ping", "echo 'Openspot cannot reach the server. Try again when the Mac is online.' >&2; exit 1")
        model.reload()

        model.tap("ping")
        try await wait("the failure") { entry("ping")?.failure != nil }
        XCTAssertEqual(entry("ping")?.failure, "Openspot cannot reach the server. Try again when the Mac is online.")

        try script("ping", "exit 0")
        model.folderChanged()
        model.tap("ping")
        try await wait("the success") { entry("ping")?.failure == nil }
    }

    func testAChangeOfTheFolderShowsANewSpotAtOnce() throws {
        model.reload()

        try script("hello", "echo")
        model.folderChanged()

        XCTAssertTrue(model.visible.contains { $0.id == "hello" })
    }

    func testAChangedScriptReadsAgainWhileTheOpenPanelShowsIt() async throws {
        try script("cups", header: "read=panel", "printf 'title=One cup\\n'")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        try await wait("the first read") { entry("cups")?.state.title == "One cup" }

        try script("cups", header: "read=panel", "printf 'title=Two cups\\n'")
        model.folderChanged()

        try await wait("the read of the changed script") { entry("cups")?.state.title == "Two cups" }
    }
}
