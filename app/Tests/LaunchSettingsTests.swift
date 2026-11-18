import XCTest
@testable import OpenspotCore

final class LaunchSettingsTests: XCTestCase {
    func testLeadingFlagsAreSettingsAndTheRestAreTheWordsOfTheCall() {
        let settings = LaunchSettings(arguments: ["--config", "/c", "--picture-on-screen", "--spots", "/s", "app", "status", "--json"])

        XCTAssertEqual(settings.words, ["app", "status", "--json"])
        XCTAssertEqual(settings.variables, ["OPENSPOT_CONFIG": "/c", "OPENSPOT_PICTURE_ON_SCREEN": "1", "OPENSPOT_SPOTS": "/s"])
        XCTAssertEqual(settings.flags, ["--config", "/c", "--picture-on-screen", "--spots", "/s"])
    }

    func testAFlagThatIsNotASettingStartsTheWords() {
        XCTAssertEqual(LaunchSettings(arguments: ["--help"]).words, ["--help"])
        XCTAssertEqual(LaunchSettings(arguments: ["--version"]).variables, [:])
        XCTAssertEqual(LaunchSettings(arguments: ["--config"]).words, ["--config"])
    }

    func testAnInheritedSettingIsDroppedAndAGivenOneTakesItsPlace() {
        let inherited = ["OPENSPOT_CONFIG": "/release", "OPENSPOT_SPOTS": "/spots", "OPENSPOT_CORE": "/core", "OPENSPOT_ID": "apps", "PATH": "/bin"]

        let environment = LaunchSettings(arguments: ["--config", "/dev"]).environment(from: inherited)

        XCTAssertEqual(environment, ["OPENSPOT_CONFIG": "/dev", "OPENSPOT_ID": "apps", "PATH": "/bin"])
    }

    func testAToolCanAddFlagsOfItsOwn() {
        let settings = LaunchSettings(arguments: ["--config", "/c", "--tool-word", "w", "--tool-on", "guide"], valued: LaunchSettings.valued.merging(["--tool-word": "OPENSPOT_TOOL_WORD"]) { $1 }, switches: ["--tool-on": "OPENSPOT_TOOL_ON"])

        XCTAssertEqual(settings.words, ["guide"])
        XCTAssertEqual(settings.environment(from: ["OPENSPOT_TOOL_WORD": "old"]), ["OPENSPOT_CONFIG": "/c", "OPENSPOT_TOOL_WORD": "w", "OPENSPOT_TOOL_ON": "1"])
    }
}
