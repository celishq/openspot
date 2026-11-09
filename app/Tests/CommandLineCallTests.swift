import XCTest
@testable import OpenspotCore

final class CommandLineCallTests: XCTestCase {
    func testACapabilityStartsItsHelperWithACallThatTheUsageDoesNotList() {
        XCTAssertEqual(CommandLineCall(arguments: ["helper", "translate"]), .helper("translate"))
        XCTAssertEqual(CommandLineCall(arguments: ["helper"]), .unknown("helper"))
        XCTAssertFalse(CommandLineCall.usage.contains("helper"))
    }

    func testEmojiCanNameATone() {
        XCTAssertEqual(CommandLineCall(arguments: ["emoji"]), .emoji(tone: .none))
        XCTAssertEqual(CommandLineCall(arguments: ["emoji", "--tone", "medium-dark"]), .emoji(tone: .mediumDark))
        XCTAssertEqual(CommandLineCall(arguments: ["emoji", "--tone", "blue"]), .unknown("emoji --tone blue"))
        XCTAssertEqual(CommandLineCall(arguments: ["emoji", "--tone"]), .unknown("emoji --tone"))
    }

    func testSymbolsTakeNoOptions() {
        XCTAssertEqual(CommandLineCall(arguments: ["symbols"]), .symbols)
        XCTAssertEqual(CommandLineCall(arguments: ["symbols", "--tone", "dark"]), .unknown("symbols --tone dark"))
    }

    func testASandboxCanNameAFile() {
        XCTAssertEqual(CommandLineCall(arguments: ["sandbox"]), .sandbox(nil))
        XCTAssertEqual(CommandLineCall(arguments: ["sandbox", "a.txt"]), .sandbox("a.txt"))
    }

    func testARenderNamesItsFile() {
        XCTAssertEqual(CommandLineCall(arguments: ["render", "a.png"]), .render("a.png", view: nil))
        XCTAssertEqual(CommandLineCall(arguments: ["render", "--view", "cups.swift", "a.png"]), .render("a.png", view: "cups.swift"))
        XCTAssertEqual(CommandLineCall(arguments: ["render", "--card", "wide", "a.png"]), .renderCard(.wide, "a.png"))
        XCTAssertEqual(CommandLineCall(arguments: ["render", "--card", "huge", "a.png"]), .unknown("render --card huge a.png"))
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
        XCTAssertEqual(CommandLineCall(arguments: ["clipboard", "copy", "/a b.mov"]), .clipboardCopy("/a b.mov"))
        XCTAssertEqual(CommandLineCall(arguments: ["clipboard", "paste"]), .clipboardPaste)
        XCTAssertEqual(CommandLineCall(arguments: ["clipboard", "copy"]), .clipboardCopy(nil))
        XCTAssertEqual(CommandLineCall(arguments: ["translate", "languages"]), .translateLanguages)
        XCTAssertEqual(CommandLineCall(arguments: ["translate"]), .translate(from: nil, to: nil))
        XCTAssertEqual(CommandLineCall(arguments: ["translate", "--from", "ru", "--to", "en"]), .translate(from: "ru", to: "en"))
        XCTAssertEqual(CommandLineCall(arguments: ["translate", "--from", "auto", "--to", "en"]), .translate(from: nil, to: "en"))
        XCTAssertEqual(CommandLineCall(arguments: ["--help"]), .help)
    }

    func testASettingBelongsToTheSpotThatRunsTheCommand() {
        let spot = ["OPENSPOT_ID": "repos"]

        XCTAssertEqual(CommandLineCall(arguments: ["setting", "get", "folder"], environment: spot), .settingGet(spot: "repos", key: "folder"))
        XCTAssertEqual(CommandLineCall(arguments: ["setting", "set", "folder", "/a b"], environment: spot), .settingSet(spot: "repos", key: "folder", value: "/a b"))
        XCTAssertEqual(CommandLineCall(arguments: ["setting", "set", "folder"], environment: spot), .settingSet(spot: "repos", key: "folder", value: nil))
        XCTAssertEqual(CommandLineCall(arguments: ["setting", "get", "--spot", "home/coffee", "size"], environment: spot), .settingGet(spot: "home/coffee", key: "size"))
        XCTAssertEqual(CommandLineCall(arguments: ["setting", "get"], environment: spot), .unknown("setting get"))
        XCTAssertEqual(CommandLineCall(arguments: ["setting", "set", "a", "b", "c"], environment: spot), .unknown("setting set a b c"))
    }

    func testASettingWithNoSpotIsRefused() {
        XCTAssertEqual(
            CommandLineCall(arguments: ["setting", "get", "folder"], environment: [:]),
            .refused("`openspot setting` needs a spot. Run it from a spot, or name one with `--spot <id>`.")
        )
    }

    func testACommandThatWaitsForThePersonIsRefusedInARead() {
        XCTAssertEqual(CommandLineCall(arguments: ["folder", "pick"], environment: [:]), .folderPick)
        XCTAssertEqual(
            CommandLineCall(arguments: ["folder", "pick"], environment: ["OPENSPOT_REASON": "sheet"]),
            .refused("`openspot folder pick` waits for the person, so it cannot run in a read. Run it from a pick or an action.")
        )
        XCTAssertEqual(
            CommandLineCall(arguments: ["color", "pick"], environment: ["OPENSPOT_REASON": "panel"]),
            .refused("`openspot color pick` waits for the person, so it cannot run in a read. Run it from a pick or an action.")
        )
    }

    func testAWindowCallReadsItsFrames() {
        XCTAssertEqual(CommandLineCall(arguments: ["window", "frame"]), .windowFrame)
        XCTAssertEqual(CommandLineCall(arguments: ["window", "move", "-1440", "25", "720", "900"]), .windowMove(WindowMove(words: ["-1440", "25", "720", "900"])!))
        XCTAssertEqual(CommandLineCall(arguments: ["window", "move", "0 0 1/4 1", "0 0 1/3 1"]), .windowMove(WindowMove(words: ["0", "0", "1/4", "1", "0", "0", "1/3", "1"])!))
        XCTAssertEqual(CommandLineCall(arguments: ["window", "move", "0", "25", "720"]), .unknown("window move 0 25 720"))
        XCTAssertEqual(CommandLineCall(arguments: ["window", "move", "0", "25", "wide", "900"]), .unknown("window move 0 25 wide 900"))
        XCTAssertEqual(CommandLineCall(arguments: ["window", "move", "0", "25", "0", "900"]), .unknown("window move 0 25 0 900"))
        XCTAssertEqual(CommandLineCall(arguments: ["window", "move", "0", "0", "1/0", "1"]), .unknown("window move 0 0 1/0 1"))
        XCTAssertEqual(CommandLineCall(arguments: ["window", "move", "0", "0", "50%%", "1"]), .unknown("window move 0 0 50%% 1"))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot window move frame..."))
    }

    func testAScreenCallReadsItsWords() {
        XCTAssertEqual(CommandLineCall(arguments: ["screen", "sources"]), .screenSources)
        XCTAssertEqual(CommandLineCall(arguments: ["screen", "shot"]), .screenShot(ScreenCapture()))
        XCTAssertEqual(CommandLineCall(arguments: ["screen", "shot", "window:front", "a.png"]), .screenShot(ScreenCapture(source: .window(.front), file: "a.png")))
        XCTAssertEqual(CommandLineCall(arguments: ["screen", "shot", "mic"]), .unknown("screen shot mic"))
        XCTAssertEqual(CommandLineCall(arguments: ["screen", "sources", "all"]), .unknown("screen sources all"))
        XCTAssertEqual(CommandLineCall(arguments: ["screen"]), .unknown("screen"))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot screen sources"))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot screen shot"))
    }

    func testAScreenCaptureIsRefusedInAReadAndTheSourcesAreNot() {
        let read = ["OPENSPOT_REASON": "panel"]

        XCTAssertEqual(CommandLineCall(arguments: ["screen", "sources"], environment: read), .screenSources)
        XCTAssertEqual(
            CommandLineCall(arguments: ["screen", "shot", "display"], environment: read),
            .refused("`openspot screen shot` captures the screen, so it cannot run in a read. Run it from a pick or an action.")
        )
    }

    func testARecordingCallReadsItsWordsAndOnlyItsStatusRunsInARead() {
        let read = ["OPENSPOT_REASON": "timer"]

        XCTAssertEqual(CommandLineCall(arguments: ["screen", "record", "start", "display:1", "mic", "talk.mp4"]), .screenRecordStart(ScreenCapture(source: .display(1), inputs: [.mic(nil)], file: "talk.mp4")))
        XCTAssertEqual(CommandLineCall(arguments: ["screen", "record", "stop"]), .screenRecordStop)
        XCTAssertEqual(CommandLineCall(arguments: ["screen", "record", "status"], environment: read), .screenRecordStatus)
        XCTAssertEqual(CommandLineCall(arguments: ["screen", "record", "start", "mic", "mic"]), .unknown("screen record start mic mic"))
        XCTAssertEqual(CommandLineCall(arguments: ["screen", "record", "stop", "now"]), .unknown("screen record stop now"))
        XCTAssertEqual(CommandLineCall(arguments: ["screen", "record"]), .unknown("screen record"))
        XCTAssertEqual(
            CommandLineCall(arguments: ["screen", "record", "start"], environment: read),
            .refused("`openspot screen record start` captures the screen, so it cannot run in a read. Run it from a pick or an action.")
        )
        XCTAssertEqual(
            CommandLineCall(arguments: ["screen", "record", "stop"], environment: read),
            .refused("`openspot screen record stop` captures the screen, so it cannot run in a read. Run it from a pick or an action.")
        )
        XCTAssertTrue(CommandLineCall.usage.contains("openspot screen record start"))
    }

    func testAnUnknownCallAsksForHelp() {
        XCTAssertEqual(CommandLineCall(arguments: ["paint"]), .unknown("paint"))
        XCTAssertEqual(CommandLineCall(arguments: ["color", "mix"]), .unknown("color mix"))
        XCTAssertEqual(CommandLineCall(arguments: ["translate", "--to"]), .unknown("translate --to"))
    }

    func testAScriptFindsTheCommandOnItsPath() {
        let environment = ScriptProcess.environment(base: ["PATH": "/usr/bin", "HOME": "/h"], app: "/A/Openspot.app/Contents/MacOS/Openspot")

        XCTAssertEqual(environment["PATH"], "/A/Openspot.app/Contents/Helpers:/usr/bin")
        XCTAssertEqual(environment["HOME"], "/h")
    }
}
