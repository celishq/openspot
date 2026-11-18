import XCTest
@testable import OpenspotCore

final class LaunchSettingsTests: XCTestCase {
    func testLeadingFlagsAreSettingsAndTheRestAreTheWordsOfTheCall() {
        let settings = LaunchSettings(arguments: ["--config", "/c", "--picture-on-screen", "--spots", "/s", "app", "status", "--json"])

        XCTAssertEqual(settings.words, ["app", "status", "--json"])
        XCTAssertEqual(settings.variables, ["OPENSPOT_CONFIG": "/c", "OPENSPOT_PICTURE_ON_SCREEN": "1", "OPENSPOT_SPOTS": "/s"])
    }

    func testAFlagThatIsNotASettingStartsTheWords() {
        XCTAssertEqual(LaunchSettings(arguments: ["--help"]).words, ["--help"])
        XCTAssertEqual(LaunchSettings(arguments: ["--version"]).variables, [:])
        XCTAssertEqual(LaunchSettings(arguments: ["--config"]).words, ["--config"])
    }

    func testTheAppDropsEveryInheritedVariableOfOpenspotAndKeepsWhatItsFlagsGive() {
        let inherited = ["OPENSPOT_CONFIG": "/release", "OPENSPOT_ID": "apps", "OPENSPOT_TOKEN": "a4", "OPENSPOT_DATA": "/d", "PATH": "/bin"]

        let environment = LaunchSettings(arguments: ["--config", "/dev"]).environment(from: inherited, keepsCallData: false)

        XCTAssertEqual(environment, ["OPENSPOT_CONFIG": "/dev", "PATH": "/bin"])
    }

    func testACallThatRunsAloneKeepsTheDataOfItsCallAndDropsInheritedSettings() {
        let inherited = ["OPENSPOT_CONFIG": "/release", "OPENSPOT_SPOTS": "/spots", "OPENSPOT_CORE": "/core", "OPENSPOT_ID": "apps", "PATH": "/bin"]

        let environment = LaunchSettings(arguments: ["--config", "/dev"]).environment(from: inherited, keepsCallData: true)

        XCTAssertEqual(environment, ["OPENSPOT_CONFIG": "/dev", "OPENSPOT_ID": "apps", "PATH": "/bin"])
    }

    func testAToolCanAddFlagsOfItsOwn() {
        let settings = LaunchSettings(arguments: ["--config", "/c", "--tool-word", "w", "--tool-on", "guide"], valued: LaunchSettings.valued.merging(["--tool-word": "OPENSPOT_TOOL_WORD"]) { $1 }, switches: ["--tool-on": "OPENSPOT_TOOL_ON"])

        XCTAssertEqual(settings.words, ["guide"])
        XCTAssertEqual(settings.environment(from: ["OPENSPOT_TOOL_WORD": "old"], keepsCallData: true), ["OPENSPOT_CONFIG": "/c", "OPENSPOT_TOOL_WORD": "w", "OPENSPOT_TOOL_ON": "1"])
    }
}
