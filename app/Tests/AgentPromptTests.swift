import XCTest
@testable import OpenspotCore

/// Proves that the prompt for an agent names the `openspot` client, which reaches the running app.
final class AgentPromptTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-prompt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testThePromptNamesTheClientBesideTheApp() throws {
        let app = folder.appendingPathComponent("Contents/MacOS/Openspot").path
        let client = folder.appendingPathComponent("Contents/Helpers/openspot")
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/sh\n".writeScript(to: client)

        XCTAssertEqual(AgentPrompt.command(of: app), client.path)
    }

    func testThePromptNamesTheAppWhenNoClientIsBesideIt() {
        let app = folder.appendingPathComponent("Contents/MacOS/Openspot").path

        XCTAssertEqual(AgentPrompt.command(of: app), app)
    }

    func testTheBuildingPromptBuildsTheSpotToTheEndWithNoQuestion() {
        let prompt = AgentPrompt(folder: folder, guide: folder, app: "openspot").building("Show the weather")

        XCTAssertTrue(prompt.hasPrefix("Build an Openspot spot that does this: Show the weather\n\(AgentPrompt.finishAlone)\n"))
        XCTAssertTrue(AgentPrompt.finishAlone.contains("Don't ask me"))
        XCTAssertTrue(AgentPrompt.finishAlone.contains("ready"))
        XCTAssertFalse(prompt.contains("questions"))
        XCTAssertTrue(prompt.contains("\"openspot\" guide"))
        XCTAssertTrue(prompt.contains(folder.path))
    }

    func testTheInterviewingPromptAsksWhatToBuildOneQuestionAtATimeThenBuildsIt() {
        let prompt = AgentPrompt(folder: folder, guide: folder, app: "openspot").interviewing()

        XCTAssertTrue(prompt.hasPrefix("Help me build an Openspot spot. Start by asking me what the spot should do"))
        XCTAssertTrue(prompt.contains("one at a time"))
        XCTAssertTrue(prompt.contains(folder.path))
        XCTAssertTrue(prompt.contains("\"openspot\" guide"))
        XCTAssertTrue(prompt.contains("\"openspot\" spot show <id>"))
        XCTAssertFalse(prompt.contains("does this:"))
    }

    func testTheChangingPromptNamesTheFileTheWishAndFinishesAlone() {
        let file = folder.appendingPathComponent("weather.spot/weather.sh")
        let prompt = AgentPrompt(folder: folder, guide: folder, app: "openspot").changing(file, wish: "Add a refresh button")

        XCTAssertTrue(prompt.hasPrefix("Change the Openspot spot in \(file.path): Add a refresh button\n\(AgentPrompt.finishChange)\n"))
        XCTAssertTrue(prompt.contains("\"openspot\" spot run weather"))
    }

    func testTheCopyStepNamesTheFolderInTheAppAndItsPlaceInTheSpotsFolder() {
        let core = URL(fileURLWithPath: "/Apps/Openspot.app/Contents/Resources/spots/cups.spot")
        let copy = folder.appendingPathComponent("cups.spot")

        let step = AgentPrompt(folder: folder, guide: folder, app: "openspot").copying(core, to: copy)

        XCTAssertTrue(step.contains(core.path))
        XCTAssertTrue(step.contains(copy.path))
        XCTAssertTrue(step.contains("same folder name"))
    }
}
