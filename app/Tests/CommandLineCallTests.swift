import XCTest
@testable import OpenspotCore

final class CommandLineCallTests: XCTestCase {
    func testATranslationServerStaysRunning() {
        XCTAssertEqual(CommandLineCall(arguments: ["translate", "--serve"]), .translateServe)
    }

    func testASandboxCanNameAFile() {
        XCTAssertEqual(CommandLineCall(arguments: ["sandbox"]), .sandbox(nil))
        XCTAssertEqual(CommandLineCall(arguments: ["sandbox", "a.txt"]), .sandbox("a.txt"))
    }

    func testARenderNamesItsFile() {
        XCTAssertEqual(CommandLineCall(arguments: ["render", "a.png"]), .render("a.png"))
        XCTAssertEqual(CommandLineCall(arguments: ["render"]), .unknown("render"))
    }

    func testASheetCheckReadsStandardInput() {
        XCTAssertEqual(CommandLineCall(arguments: ["check", "--sheet"]), .checkSheet)
    }

    func testNoArgumentsAndSystemFlagsStartTheApp() {
        XCTAssertNil(CommandLineCall(arguments: []))
        XCTAssertNil(CommandLineCall(arguments: ["-NSDocumentRevisionsDebugMode", "YES"]))
    }

    func testReadsEachCall() {
        XCTAssertEqual(CommandLineCall(arguments: ["check"]), .check(nil))
        XCTAssertEqual(CommandLineCall(arguments: ["check", "/a"]), .check("/a"))
        XCTAssertEqual(CommandLineCall(arguments: ["catalog"]), .catalog)
        XCTAssertEqual(CommandLineCall(arguments: ["color", "pick"]), .colorPick)
        XCTAssertEqual(CommandLineCall(arguments: ["translate", "languages"]), .translateLanguages)
        XCTAssertEqual(CommandLineCall(arguments: ["translate"]), .translate(from: nil, to: nil))
        XCTAssertEqual(CommandLineCall(arguments: ["translate", "--from", "ru", "--to", "en"]), .translate(from: "ru", to: "en"))
        XCTAssertEqual(CommandLineCall(arguments: ["translate", "--from", "auto", "--to", "en"]), .translate(from: nil, to: "en"))
        XCTAssertEqual(CommandLineCall(arguments: ["--help"]), .help)
    }

    func testAnUnknownCallAsksForHelp() {
        XCTAssertEqual(CommandLineCall(arguments: ["paint"]), .unknown("paint"))
        XCTAssertEqual(CommandLineCall(arguments: ["color", "mix"]), .unknown("color mix"))
        XCTAssertEqual(CommandLineCall(arguments: ["translate", "--to"]), .unknown("translate --to"))
    }

    func testAScriptFindsTheCommandOnItsPath() {
        let environment = PluginRun.environment(base: ["PATH": "/usr/bin", "HOME": "/h"], app: "/A/Openspot.app/Contents/MacOS/Openspot")

        XCTAssertEqual(environment["PATH"], "/A/Openspot.app/Contents/Helpers:/usr/bin")
        XCTAssertEqual(environment["HOME"], "/h")
    }
}
