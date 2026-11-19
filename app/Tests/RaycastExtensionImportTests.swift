import XCTest
@testable import OpenspotCore

final class RaycastExtensionImportTests: XCTestCase {
    private var root: URL!

    private var repo: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private var config: URL {
        root.appendingPathComponent("home/.config/openspot")
    }

    private var extensions: URL {
        root.appendingPathComponent("home/.config/raycast/extensions")
    }

    private var environment: [String: String] {
        ["OPENSPOT_CONFIG": config.path, "OPENSPOT_SPOTS": config.appendingPathComponent("spots").path, "OPENSPOT_CORE": repo.appendingPathComponent("spots").path,
         "OPENSPOT_EXAMPLES": repo.appendingPathComponent("examples").path, "HOME": root.appendingPathComponent("home").path, "PWD": root.path, "PATH": "/usr/bin:/bin"]
    }

    override func setUpWithError() throws {
        root = try temporaryFolder()
        try FileManager.default.createDirectory(at: config.appendingPathComponent("spots"), withIntermediateDirectories: true)
        try install("0e43920f", name: "translate", title: "Google Translate", description: "Translate text with Google Translate.", commands: [("translate", "Translate", "view")])
        try install("320f40ef", name: "spotify-player", title: "Spotify Player", description: "Control Spotify playback.", commands: [("nowPlaying", "Now Playing", "view"), ("next", "Next", "no-view")])
        try install("a9696c4c", name: "linear", title: "Linear", description: "Create, search and update Linear issues.", commands: [("create-issue", "Create Issue", "view"), ("unread-notifications", "Unread Notifications", "menu-bar")])
        try FileManager.default.createDirectory(at: extensions.appendingPathComponent("node_modules/react"), withIntermediateDirectories: true)
        try install("b1c2d3e4", name: "caffeinate", title: "Caffeinate", description: "Keep your Mac awake.", commands: [("caffeinate", "Caffeinate", "no-view")])
        try FileManager.default.copyItem(at: repo.appendingPathComponent("spots/translate.spot"), to: config.appendingPathComponent("spots/translate.spot"))
    }

    private func install(_ folder: String, name: String, title: String, description: String, commands: [(String, String, String)]) throws {
        let url = extensions.appendingPathComponent(folder)
        try FileManager.default.createDirectory(at: url.appendingPathComponent("assets"), withIntermediateDirectories: true)
        let list = commands.map { #"{"name":"\#($0.0)","title":"\#($0.1)","mode":"\#($0.2)","description":"\#($0.1) in \#(title)"}"# }.joined(separator: ",")
        try #"{"name":"\#(name)","title":"\#(title)","description":"\#(description)","icon":"icon.png","commands":[\#(list)]}"#.write(to: url.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: url.appendingPathComponent("assets/icon.png"))
    }

    private func answer(_ arguments: [String]) async throws -> CommandAnswer {
        let call = try XCTUnwrap(CommandLineCall(arguments: arguments, environment: environment))
        let work = try XCTUnwrap(CommandAPI(mac: Mac(), places: .test(environment), rates: .offline).work(for: call, request: .test(arguments, in: environment), input: { "" }))
        return await work()
    }

    private func blocks(_ answer: CommandAnswer) -> [TextBlock] {
        TextBlock.blocks(in: answer.output)
    }

    func testEachExtensionGetsTheSpotThatDoesItsJobOrIsMadeWithAI() async throws {
        let answer = try await answer(["import", "extensions", extensions.path])
        let rows = blocks(answer)

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(rows.map { "\($0.value("row") ?? "") \($0.value("outcome") ?? "") \($0.value("spot") ?? "")" }, [
            "caffeinate get caffeinate",
            "translate use translate",
            "spotify-player get now-playing",
            "linear make "
        ])
        XCTAssertEqual(rows[0].value("detail"), "→ Caffeinate · turned off")
        XCTAssertEqual(rows[1].value("title"), "Google Translate")
        XCTAssertEqual(rows[1].value("detail"), "→ Translate")
        XCTAssertEqual(rows[2].value("detail"), "→ Now playing · in the Store")
        XCTAssertEqual(rows[3].value("detail"), "Create, search and update Linear issues.")
        XCTAssertEqual(rows[3].value("icon"), extensions.appendingPathComponent("a9696c4c/assets/icon.png").path)
        XCTAssertEqual(rows[3].value("folder"), extensions.appendingPathComponent("a9696c4c").path)
    }

    func testAFolderWithNoExtensionsListsNone() async throws {
        let answer = try await answer(["import", "extensions", root.appendingPathComponent("home/.config/raycast/none").path])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(blocks(answer).count, 0)
    }

    func testThePromptHandsEachExtensionToTheAgentWithItsSourceAndTheBlocksToUse() async throws {
        let linear = extensions.appendingPathComponent("a9696c4c").path
        let spotify = extensions.appendingPathComponent("320f40ef").path

        let one = try await answer(["prompt", "convert", linear])
        let two = try await answer(["prompt", "convert", linear, spotify])

        XCTAssertEqual(one.code, 0, one.errors)
        XCTAssertTrue(one.output.hasPrefix("Turn this Raycast extension into an Openspot spot."), one.output)
        XCTAssertTrue(one.output.contains("Linear (\(linear)): Create, search and update Linear issues."), one.output)
        XCTAssertTrue(one.output.contains("Create Issue, Unread Notifications (menu bar)"), one.output)
        XCTAssertTrue(one.output.contains("sourcesContent"), one.output)
        XCTAssertTrue(one.output.contains("Its icon: \(linear)/assets/icon.png."), one.output)
        XCTAssertTrue(one.output.contains("Copy the icon of each extension into its spot folder"), one.output)
        XCTAssertTrue(one.output.contains("Don't ask me anything."), one.output)
        XCTAssertTrue(two.output.hasPrefix("Turn each of these 2 Raycast extensions into an Openspot spot of its own."), two.output)
        XCTAssertTrue(two.output.contains("Spotify Player (\(spotify))"), two.output)
    }

    func testThePromptNamesAFolderThatIsNotAnExtension() async throws {
        let answer = try await answer(["prompt", "convert", root.path])

        XCTAssertEqual(answer.code, 1)
        XCTAssertTrue(answer.errors.contains("is not a Raycast extension"), answer.errors)
    }
}
