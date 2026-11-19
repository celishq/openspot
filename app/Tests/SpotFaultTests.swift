import XCTest
@testable import OpenspotCore

@MainActor
final class SpotFaultTests: XCTestCase {
    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: FakeHost!
    private var model: SpotsModel!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-fault-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        let tools = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        for (name, body) in [("pbcopy", "cat > '\(folder.path)/clipboard'"), ("open", "echo \"$@\" > '\(folder.path)/opened'")] {
            try "#!/bin/sh\n\(body)\n".writeScript(to: tools.appendingPathComponent(name))
        }
        suite = "openspot-fault-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        host = FakeHost()
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path],
            home: folder,
            defaults: defaults
        )
        model = SpotsModel(host: host, files: files, runs: SpotRuns(environment: ProcessInfo.processInfo.environment.merging(["PATH": "\(tools.path):/usr/bin:/bin"]) { _, new in new }, stopPause: 0.2))
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

    private func script(_ name: String, toml: String = "", _ body: String) throws {
        try TestSpot(toml: toml, body: "\(body)").write(to: spots.spotFile(name))
    }

    private func entry(_ id: String) -> SpotsModel.Entry? {
        model.entries.first { $0.id == id }
    }

    private func saved(_ name: String) -> String? {
        try? String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
    }

    private func openFault() async throws -> SheetParts {
        try script("weather", toml: "mode = 'huge'", "echo")
        await model.reload()
        model.isShown = true
        model.press("weather")
        try await wait("the fault sheet") { model.openParts != nil }
        return try XCTUnwrap(model.openParts)
    }

    func testAFileThatDoesNotLoadKeepsAWideCardThatSaysHowToFixIt() async throws {
        try script("weather", toml: "mode = 'huge'", "echo")

        await model.reload()

        let card = try XCTUnwrap(entry("weather"))
        XCTAssertEqual(card.state.title, "Fix")
        XCTAssertEqual(card.state.subtitle, "Weather")
        XCTAssertEqual(card.size, .wide)
        XCTAssertTrue(card.isOnGrid)
        XCTAssertEqual(host.notes, [])
    }

    func testAFaultCardStaysWideWhenThePersonChoseTheSmallSize() async throws {
        try script("weather", toml: "mode = 'huge'", "echo")
        await model.reload()

        model.prefer(.small, for: "weather")

        XCTAssertEqual(entry("weather")?.size, .wide)
    }

    func testTheFaultSheetShowsTheFileAndEachFaultWithItsFixes() async throws {
        let sheet = try await openFault()

        let text = sheet.parts.compactMap { if case .text(let value, _, _) = $0.control { value } else { nil } }.joined()
        XCTAssertTrue(text.contains(spots.spotFile("weather").path))
        XCTAssertTrue(text.contains("Weather has an unknown mode: huge. Use once or stay"))
        XCTAssertEqual(Set(sheet.parts.map(\.id)).intersection(["fix", "edit"]), ["fix", "edit"])
    }

    func testCopyPromptForAICopiesAPromptThatNamesTheFileTheFaultAndTheCheck() async throws {
        let sheet = try await openFault()
        let fix = try XCTUnwrap(sheet.parts.first { $0.id == "fix" })
        XCTAssertEqual(fix.title, "Copy prompt for AI")

        model.pressPart(fix)
        try await wait("the whole prompt") { saved("clipboard")?.contains("what the spot runs on my computer.") == true }

        let prompt = try XCTUnwrap(saved("clipboard"))
        XCTAssertTrue(prompt.contains(spots.spotFile("weather").path))
        XCTAssertTrue(prompt.contains("Weather has an unknown mode: huge. Use once or stay"))
        XCTAssertTrue(prompt.contains("check"))
    }

    func testEditOpensTheFileInTheTextEditor() async throws {
        let sheet = try await openFault()

        model.pressPart(try XCTUnwrap(sheet.parts.first { $0.id == "edit" }))
        try await wait("the editor") { saved("opened")?.hasSuffix("\n") == true }

        XCTAssertEqual(saved("opened"), "-t \(spots.spotFile("weather").path)\n")
    }

    func testAFileThatLoadsAgainTakesBackItsCard() async throws {
        try script("weather", toml: "mode = 'huge'", "echo")
        await model.reload()

        try script("weather", toml: "mode = 'once'", "echo")
        await model.spotsChanged()

        XCTAssertEqual(entry("weather")?.state.title, "Weather")
        XCTAssertNil(entry("weather")?.spot.fault)
    }

    func testAFailedRunMarksItsCardUntilARunSucceeds() async throws {
        try script("ping", "echo 'Openspot cannot reach the server. Try again when the Mac is online.' >&2; exit 1")
        await model.reload()

        model.tap("ping")
        try await wait("the failure") { entry("ping")?.failure != nil }
        XCTAssertEqual(entry("ping")?.failure, "Openspot cannot reach the server. Try again when the Mac is online.")
        model.closeSheet(moving: false)

        try script("ping", "exit 0")
        await model.spotsChanged()
        model.tap("ping")
        try await wait("the success") { entry("ping")?.failure == nil }
    }

    func testAChangeOfTheFolderShowsANewSpotAtOnce() async throws {
        await model.reload()

        try script("hello", "echo")
        await model.spotsChanged()

        XCTAssertTrue(model.visible.contains { $0.id == "hello" })
    }

    func testAChangedScriptReadsAgainWhileTheOpenPanelShowsIt() async throws {
        try script("cups", toml: "on = ['panel.open']", "printf 'frame=\\ntitle=One cup\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        try await wait("the first read") { entry("cups")?.state.title == "One cup" }

        try script("cups", toml: "on = ['panel.open']", "printf 'frame=\\ntitle=Two cups\\n'")
        await model.spotsChanged()

        try await wait("the read of the changed script") { entry("cups")?.state.title == "Two cups" }
    }
}
