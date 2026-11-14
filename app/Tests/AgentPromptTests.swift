import XCTest
@testable import OpenspotCore

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
}
