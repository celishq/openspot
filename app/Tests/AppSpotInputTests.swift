import XCTest
@testable import OpenspotCore

final class AppSpotInputTests: BuiltInCase {
    func testNoSpotOfTheAppRunsACommandThatAPageAnArgumentOrStdinHolds() async throws {
        let made = root.appendingPathComponent("made")
        let text = "x[$(touch '\(made.path)')]`touch '\(made.path)'`;touch '\(made.path)';"
        let place = SpotsFolder(url: root.appendingPathComponent("none"), core: repoSpots)
        let scripts = try place.scan().scripts.filter { $0.isBuiltIn && $0.url.pathExtension == "sh" }
        XCTAssertGreaterThan(scripts.count, 4)

        for script in scripts {
            for arguments in [["read"], [text], ["read", text]] {
                _ = try? await runs.answer(of: script, SpotAction(arguments: arguments), input: "id=\(text)\nvalue=\(text)\n", limit: 30, variables: ["OPENSPOT_PAGE": text, "OPENSPOT_VALUE": text])
            }
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: made.path))
    }
}
