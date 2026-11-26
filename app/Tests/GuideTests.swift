import XCTest
@testable import OpenspotCore

final class GuideTests: XCTestCase {
    private let pages = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Help")
    private var api: CommandAPI!

    override func setUpWithError() throws {
        let folder = try temporaryFolder()
        let file = folder.appendingPathComponent("DOCS.md")
        try "# Show a list\n\nPrint rows.\n".write(to: file, atomically: true, encoding: .utf8)
        api = CommandAPI(mac: Mac(guide: file, pages: pages), places: .test(["OPENSPOT_CONFIG": folder.path]))
    }

    private func answer(_ arguments: [String]) async throws -> CommandAnswer {
        try await XCTUnwrap(api.work(for: .test(arguments), input: { "" }))()
    }

    func testEachCommandThatTheBuiltGuidePrintsOpensAPart() throws {
        let folder = try temporaryFolder()
        let out = folder.appendingPathComponent("DOCS.md")
        let script = Process()
        script.executableURL = URL(fileURLWithPath: "/bin/sh")
        script.arguments = [pages.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("scripts/guide.sh").path, out.path]
        try script.run()
        script.waitUntilExit()
        let guide = Guide(text: try String(contentsOf: out, encoding: .utf8), pages: [:])
        let regex = try NSRegularExpression(pattern: "`openspot guide ([^`]+)`")
        let addresses = guide.topics.flatMap { topic in
            regex.matches(in: topic.text, range: NSRange(topic.text.startIndex..., in: topic.text)).compactMap { Range($0.range(at: 1), in: topic.text).map { String(topic.text[$0]) } }
        }

        XCTAssertGreaterThan(addresses.count, 100)
        XCTAssertEqual(addresses.filter { guide.topic($0) == nil }, [])
    }

    func testEachPageOfANounIsATopicOfTheGuide() async throws {
        let topics = try await answer(["guide", "--topics"])
        let screen = try await answer(["guide", "screen"])

        XCTAssertEqual(topics.output, "show-a-list    Show a list\ncalendar       openspot calendar and openspot reminders\ncommands       The openspot commands\nscreen         openspot screen\nstats          openspot spot stats\n")
        XCTAssertTrue(screen.output.hasPrefix("# openspot screen"), screen.output)
        XCTAssertTrue(screen.output.contains("(S11)"))
    }

    func testTheHelpOfANounFindsItsPageWithNoGuideFile() async throws {
        let bare = CommandAPI(mac: Mac(guide: nil, pages: pages), places: .test(["OPENSPOT_CONFIG": try temporaryFolder().path]))

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
