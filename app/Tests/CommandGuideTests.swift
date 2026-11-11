import XCTest
@testable import OpenspotCore

/// Proves the guides that `openspot help <noun>` prints, from the guide folder that the app ships.
final class CommandGuideTests: XCTestCase {
    private let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Help")

    func testEachNounPrintsTheGuideOfItsFile() throws {
        let guides = CommandGuide(folder: folder)

        XCTAssertTrue(try guides.text(of: "screen").hasPrefix("# openspot screen"))
        XCTAssertTrue(try guides.text(of: "calendar").hasPrefix("# openspot calendar and openspot reminders"))
        XCTAssertEqual(try guides.text(of: "reminders"), try guides.text(of: "calendar"))
    }

    func testEachNounHasAGuideFileThatKeepsItsRuleIDs() throws {
        let guides = CommandGuide(folder: folder)

        for noun in CommandGuide.nouns {
            XCTAssertFalse(try guides.text(of: noun).isEmpty, noun)
        }
        XCTAssertTrue(try guides.text(of: "screen").contains("(S11)"))
        XCTAssertTrue(try guides.text(of: "calendar").contains("(E9)"))
    }

    func testAnUnknownNounFailsAndNamesTheNounsThatHaveAGuide() {
        XCTAssertThrowsError(try CommandGuide(folder: folder).text(of: "window")) { error in
            XCTAssertEqual(
                (error as? PluginError)?.reason,
                "openspot has no guide for window. Run openspot help calendar, openspot help reminders or openspot help screen."
            )
        }
    }
}
