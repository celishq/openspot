import XCTest
@testable import OpenspotCore

final class GuideTests: XCTestCase {
    private let pages = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Help")
    private var api: CommandAPI!

    override func setUpWithError() throws {
        let folder = try temporaryFolder()
        let file = folder.appendingPathComponent("GUIDE.md")
        try "# Openspot guide\n\n## Show a list\n\nPrint rows.\n".write(to: file, atomically: true, encoding: .utf8)
        api = CommandAPI(mac: Mac(guide: file, pages: pages), places: .test(["OPENSPOT_CONFIG": folder.path]), rates: .offline)
    }

    private func answer(_ arguments: [String]) async throws -> CommandAnswer {
        try await XCTUnwrap(api.work(for: .test(arguments), input: { "" }))()
    }

    func testEachPageOfANounIsATopicOfTheGuide() async throws {
        let topics = try await answer(["guide", "--topics"])
        let screen = try await answer(["guide", "screen"])

        XCTAssertEqual(topics.output, "show-a-list    Show a list\ncalendar       openspot calendar and openspot reminders\nscreen         openspot screen\n")
        XCTAssertTrue(screen.output.hasPrefix("# openspot screen"), screen.output)
        XCTAssertTrue(screen.output.contains("(S11)"))
    }

    func testTheHelpOfANounFindsItsPageWithNoGuideFile() async throws {
        let bare = CommandAPI(mac: Mac(guide: nil, pages: pages), places: .test(["OPENSPOT_CONFIG": try temporaryFolder().path]), rates: .offline)

        let screen = try await XCTUnwrap(bare.work(for: .test(["help", "screen"]), input: { "" }))()

        XCTAssertTrue(screen.output.contains("\n# openspot screen"), screen.output)
    }

    func testTheHelpOfANounPrintsItsVerbsThenItsPage() async throws {
        let reminders = try await answer(["help", "reminders"])
        let calendar = try await answer(["guide", "calendar"])
        let clipboard = try await answer(["help", "clipboard"])

        XCTAssertTrue(reminders.output.hasPrefix("openspot reminders due"), reminders.output)
        XCTAssertTrue(reminders.output.hasSuffix("\n" + calendar.output))
        XCTAssertTrue(calendar.output.contains("(E9)"))
        XCTAssertTrue(clipboard.output.hasPrefix("openspot clipboard copy"))
        XCTAssertFalse(clipboard.output.contains("\n#"))
    }
}
