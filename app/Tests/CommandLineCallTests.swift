import XCTest
@testable import OpenspotCore

final class CommandLineCallTests: XCTestCase {
    func testACapabilityStartsItsHelperWithACallThatTheUsageDoesNotList() {
        XCTAssertEqual(CommandLineCall(arguments: ["helper", "translate"])?.value as? HelperCall, .capability("translate"))
        XCTAssertEqual(CommandLineCall(arguments: ["helper"])?.value as? CallFault, .unknown(["helper"]))
        XCTAssertFalse(CommandLineCall.usage.contains("helper"))
    }

    func testTheAppDrawsAPictureBookWithAHelperCallThatTheUsageDoesNotList() {
        XCTAssertEqual(CommandLineCall(arguments: ["helper", "glyphs", "24", "19.2", "/tmp/book"])?.value as? HelperCall, .glyphs(side: 24, fontSize: 19.2, path: "/tmp/book"))
        XCTAssertEqual(CommandLineCall(arguments: ["helper", "glyphs", "big", "19.2", "/tmp/book"])?.value as? CallFault, .unknown(["helper", "glyphs", "big", "19.2", "/tmp/book"]))
        XCTAssertEqual(CommandLineCall(arguments: ["helper", "glyphs", "24"])?.value as? CallFault, .unknown(["helper", "glyphs", "24"]))
        XCTAssertFalse(CommandLineCall.usage.contains("glyphs"))
    }

    func testGridEditOpensEditSpotsAndSpotStoreIsGone() {
        XCTAssertEqual(CommandLineCall(arguments: ["grid", "edit"])?.value as? GridCall, .edit)
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "store"])?.value as? CallFault, .unknown(["spot", "store"]))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot grid edit"))
    }

    func testStoreListsItsSpotsAndGetsOne() {
        XCTAssertEqual(CommandLineCall(arguments: ["store", "list"])?.value as? StoreCall, .list(.frame))
        XCTAssertEqual(CommandLineCall(arguments: ["store", "list", "--json"])?.value as? StoreCall, .list(.json))
        XCTAssertEqual(CommandLineCall(arguments: ["store", "get", "timer"])?.value as? StoreCall, .get("timer", isConfirmed: false))
        XCTAssertEqual(CommandLineCall(arguments: ["store", "get", "timer", "--replace"])?.value as? StoreCall, .get("timer", isConfirmed: false, clash: .replace))
        XCTAssertEqual(CommandLineCall(arguments: ["store", "get", "timer", "--keep-both", "--yes"])?.value as? StoreCall, .get("timer", isConfirmed: true, clash: .keepBoth))
        XCTAssertEqual(CommandLineCall(arguments: ["store", "get", "timer", "--replace", "--keep-both"])?.value as? CallFault, .unknown(["store", "get", "timer", "--replace", "--keep-both"]))
        XCTAssertEqual(CommandLineCall(arguments: ["store", "get", "timer", "--yes"])?.value as? StoreCall, .get("timer", isConfirmed: true))
        XCTAssertEqual(CommandLineCall(arguments: ["store", "update"])?.value as? StoreCall, .update(nil, isConfirmed: false))
        XCTAssertEqual(CommandLineCall(arguments: ["store", "update", "clock", "--yes"])?.value as? StoreCall, .update("clock", isConfirmed: true))
        XCTAssertEqual(CommandLineCall(arguments: ["store", "revert", "clock"])?.value as? StoreCall, .revert("clock", isConfirmed: false))
        XCTAssertEqual(CommandLineCall(arguments: ["store", "revert"])?.value as? CallFault, .unknown(["store", "revert"]))
        XCTAssertEqual(CommandLineCall(arguments: ["store", "add", "/a"])?.value as? StoreCall, .add("/a"))
        XCTAssertEqual(CommandLineCall(arguments: ["store", "remove", "/a"])?.value as? StoreCall, .remove("/a"))
        XCTAssertEqual(CommandLineCall(arguments: ["store", "folders", "--json"])?.value as? StoreCall, .folders(.json))
    }

    func testAccountPrintsItsFactsAndReachesTheKey() {
        XCTAssertEqual(CommandLineCall(arguments: ["account", "show"])?.value as? AccountCall, .status(.frame))
        XCTAssertEqual(CommandLineCall(arguments: ["account", "show", "--json"], environment: [:], reason: "sheet.open")?.value as? AccountCall, .status(.json))
        XCTAssertEqual(CommandLineCall(arguments: ["account", "open"])?.value as? CallFault, .unknown(["account", "open"]))
        XCTAssertEqual(CommandLineCall(arguments: ["account", "new", "tony"])?.value as? AccountCall, .make(handle: "tony"))
        XCTAssertEqual(CommandLineCall(arguments: ["account", "sign-out"])?.value as? AccountCall, .signOut)
        XCTAssertEqual(CommandLineCall(arguments: ["account", "sync", "off"])?.value as? AccountCall, .sync(false))
        for verb in ["words", "choices", "checked", "phrase", "sign-in", "sync"] {
            XCTAssertEqual(CommandLineCall(arguments: ["account", verb])?.value as? CallFault, .unknown(["account", "\(verb)"]))
        }
        XCTAssertEqual(CommandLineCall(arguments: ["account", "check", "4", "13"])?.value as? CallFault, .unknown(["account", "check", "4", "13"]))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot account show [--json]"))
        XCTAssertFalse(CommandLineCall.usage.contains("openspot account words"))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot account sign-out"))
    }

    func testEmojiCanNameATone() {
        XCTAssertEqual(CommandLineCall(arguments: ["emoji", "list"])?.value as? EmojiCall, .rows(tone: .none))
        XCTAssertEqual(CommandLineCall(arguments: ["emoji", "list", "--tone", "medium-dark"])?.value as? EmojiCall, .rows(tone: .mediumDark))
        XCTAssertEqual(CommandLineCall(arguments: ["emoji", "list", "--tone", "blue"])?.value as? CallFault, .unknown(["emoji", "list", "--tone", "blue"]))
        XCTAssertEqual(CommandLineCall(arguments: ["emoji", "list", "--tone"])?.value as? CallFault, .unknown(["emoji", "list", "--tone"]))
    }

    func testSymbolsTakeNoOptions() {
        XCTAssertEqual(CommandLineCall(arguments: ["symbols", "list"])?.value as? SymbolsCall, .rows)
        XCTAssertEqual(CommandLineCall(arguments: ["symbols", "--tone", "dark"])?.value as? CallFault, .unknown(["symbols", "--tone", "dark"]))
    }

    func testThePlaygroundCanNameAFile() {
        XCTAssertEqual(CommandLineCall(arguments: ["playground", "open"])?.value as? PlaygroundCommand, .open(nil))
        XCTAssertEqual(CommandLineCall(arguments: ["playground", "open", "a.txt"])?.value as? PlaygroundCommand, .open("a.txt"))
    }

    func testARenderNamesItsFile() {
        XCTAssertEqual(CommandLineCall(arguments: ["render", "sheet", "a.png"])?.value as? RenderCall, .sheet("a.png", view: nil))
        XCTAssertEqual(CommandLineCall(arguments: ["render", "sheet", "--view", "cups.swift", "a.png"])?.value as? RenderCall, .sheet("a.png", view: "cups.swift"))
        XCTAssertEqual(CommandLineCall(arguments: ["render", "card", "wide", "a.png"])?.value as? RenderCall, .card(.wide, "a.png"))
        XCTAssertEqual(CommandLineCall(arguments: ["render", "card", "huge", "a.png"])?.value as? CallFault, .unknown(["render", "card", "huge", "a.png"]))
        XCTAssertEqual(CommandLineCall(arguments: ["render", "panel", "a.png"])?.value as? RenderCall, .panel("a.png"))
        XCTAssertEqual(
            CommandLineCall(arguments: ["render", "panel", "--arrange", "--search", "sn", "--swap", "clock", "a.png"])?.value as? RenderCall,
            .panel("a.png", scene: PanelScene(isArranging: true, search: "sn", swap: "clock"))
        )
        XCTAssertEqual(CommandLineCall(arguments: ["render", "panel", "--search", "home city", "--light", "a.png"])?.value as? RenderCall, .panel("a.png", scene: PanelScene(search: "home city", isLight: true)))
        XCTAssertNil(CommandLineCall(arguments: ["render", "panel", "--swap", "clock", "a.png"])?.value as? RenderCall)
        XCTAssertEqual(CommandLineCall(arguments: ["render", "store", "a.png"])?.value as? RenderCall, .store("a.png", place: nil, spot: nil, review: nil))
        XCTAssertEqual(CommandLineCall(arguments: ["render", "settings", "a.png"])?.value as? RenderCall, .settings(at: nil, path: "a.png", isLight: false))
        XCTAssertEqual(CommandLineCall(arguments: ["render", "settings", "--at", "access/screen", "--light", "a.png"])?.value as? RenderCall, .settings(at: "access/screen", path: "a.png", isLight: true))
        XCTAssertEqual(CommandLineCall(arguments: ["render"])?.value as? CallFault, .unknown(["render"]))
    }

    func testTheSpotNounMakesRunsShowsAndLogsOneSpot() {
        XCTAssertEqual(CommandLineCall(arguments: ["guide"])?.value as? GuideCall, .text)
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "new", "Weather"])?.value as? SpotCall, .new(name: "Weather", starter: .button))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "new", "Weather", "--from", "list"])?.value as? SpotCall, .new(name: "Weather", starter: .list))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "new", "Weather", "--from", "tree"])?.value as? CallFault, .unknown(["spot", "new", "Weather", "--from", "tree"]))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "run", "weather"])?.value as? SpotCall, .run(id: "weather", arguments: []))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "run", "weather", "open", "today"])?.value as? SpotCall, .run(id: "weather", arguments: ["open", "today"]))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "open", "weather", "--select"])?.value as? SpotCall, .show("weather"))
        XCTAssertNil(CommandLineCall(arguments: ["spot", "open", "settings", "--at", "spot/notes"])?.value as? SpotCall)
        XCTAssertNil(CommandLineCall(arguments: ["spot", "settings", "weather"])?.value as? SpotCall)
        XCTAssertNil(CommandLineCall(arguments: ["spot", "allow", "weather"])?.value as? SpotCall)
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "allow", "weather", "clipboard"])?.value as? SpotCall, .allow("weather", use: "clipboard"))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "edit", "weather"])?.value as? SpotCall, .act(.edit, "weather"))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "prompt", "weather"])?.value as? SpotCall, .act(.prompt, "weather"))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "share", "weather"])?.value as? SpotCall, .act(.share, "weather"))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "delete", "weather"])?.value as? SpotCall, .act(.delete, "weather"))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "log", "weather"])?.value as? SpotCall, .log("weather"))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "stats"])?.value as? SpotCall, .stats(days: 1, spot: nil, format: .frame))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "stats", "--days", "7", "--spot", "home/coffee", "--json"])?.value as? SpotCall, .stats(days: 7, spot: "home/coffee", format: .json))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "stats", "--days", "1000000"])?.value as? SpotCall, .stats(days: 90, spot: nil, format: .frame))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "stats", "weather"])?.value as? CallFault, .unknown(["spot", "stats", "weather"]))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "stats", "--days", "0"])?.value as? CallFault, .unknown(["spot", "stats", "--days", "0"]))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "stats", "--json", "--json"])?.value as? CallFault, .unknown(["spot", "stats", "--json", "--json"]))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "stats", "--by", "version", "--openmetrics"])?.value as? SpotCall, .stats(days: 1, spot: nil, format: .metrics, byVersion: true))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "stats", "--by", "day"])?.value as? CallFault, .unknown(["spot", "stats", "--by", "day"]))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "stats", "--json", "--openmetrics"])?.value as? CallFault, .unknown(["spot", "stats", "--json", "--openmetrics"]))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot spot stats"))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "open", "weather", "--all"])?.value as? CallFault, .unknown(["spot", "open", "weather", "--all"]))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot spot run"))
    }

    func testACheckCanPrintJSONAndARenderCanNameAnInstalledSpot() {
        XCTAssertEqual(CommandLineCall(arguments: ["check", "spots", "--json"])?.value as? CheckCall, .folder(nil, form: .json))
        XCTAssertEqual(CommandLineCall(arguments: ["check", "spots", "--json", "spots"])?.value as? CheckCall, .folder("spots", form: .json))
        XCTAssertEqual(CommandLineCall(arguments: ["render", "spot", "weather", "a.png"])?.value as? RenderCall, .spot(id: "weather", size: nil, path: "a.png"))
        XCTAssertEqual(CommandLineCall(arguments: ["render", "spot", "weather", "--card", "wide", "a.png"])?.value as? RenderCall, .spot(id: "weather", size: .wide, path: "a.png"))
        XCTAssertEqual(CommandLineCall(arguments: ["render", "spot", "weather", "--light", "a.png"])?.value as? RenderCall, .spot(id: "weather", size: nil, path: "a.png", isLight: true))
        XCTAssertEqual(CommandLineCall(arguments: ["render", "spot", "weather", "--card", "wide", "--light", "a.png"])?.value as? RenderCall, .spot(id: "weather", size: .wide, path: "a.png", isLight: true))
        XCTAssertEqual(CommandLineCall(arguments: ["render", "spot", "weather", "--card", "huge", "a.png"])?.value as? CallFault, .unknown(["render", "spot", "weather", "--card", "huge", "a.png"]))
    }

    func testASheetCheckReadsStandardInput() {
        XCTAssertEqual(CommandLineCall(arguments: ["check", "sheet"])?.value as? CheckCall, .sheet)
    }

    func testNoArgumentsAndSystemFlagsStartTheApp() {
        XCTAssertNil(CommandLineCall(arguments: []))
        XCTAssertNil(CommandLineCall(arguments: ["-NSDocumentRevisionsDebugMode", "YES"]))
    }

    func testReadsEachCall() {
        XCTAssertEqual(CommandLineCall(arguments: ["check", "spots"])?.value as? CheckCall, .folder(nil, form: .frame))
        XCTAssertEqual(CommandLineCall(arguments: ["check", "spots", "/a"])?.value as? CheckCall, .folder("/a", form: .frame))
        XCTAssertEqual(CommandLineCall(arguments: ["color", "pick"])?.value as? ColorCall, .pick)
        XCTAssertEqual(CommandLineCall(arguments: ["clipboard", "copy", "/a b.mov"])?.value as? ClipboardCall, .copy("/a b.mov"))
        XCTAssertEqual(CommandLineCall(arguments: ["clipboard", "paste"])?.value as? ClipboardCall, .paste)
        XCTAssertEqual(CommandLineCall(arguments: ["clipboard", "copy"])?.value as? ClipboardCall, .copy(nil))
        XCTAssertEqual(CommandLineCall(arguments: ["clipboard", "read"])?.value as? ClipboardCall, .read(within: nil))
        XCTAssertEqual(CommandLineCall(arguments: ["translate", "languages"])?.value as? TranslateCall, .languages)
        XCTAssertEqual(CommandLineCall(arguments: ["translate", "text"])?.value as? TranslateCall, .text(from: nil, to: nil))
        XCTAssertEqual(CommandLineCall(arguments: ["translate", "text", "--from", "ru", "--to", "en"])?.value as? TranslateCall, .text(from: "ru", to: "en"))
        XCTAssertEqual(CommandLineCall(arguments: ["translate", "text", "--from", "auto", "--to", "en"])?.value as? TranslateCall, .text(from: nil, to: "en"))
        XCTAssertEqual(CommandLineCall(arguments: ["--help"])?.value as? HelpCall, .list)
    }

    func testHelpCanNameTheNounWhoseGuideItPrints() {
        XCTAssertEqual(CommandLineCall(arguments: ["help"])?.value as? HelpCall, .list)
        XCTAssertEqual(CommandLineCall(arguments: ["help", "reminders"])?.value as? HelpCall, .verbs("reminders", verb: []))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot help [noun [verb]] [--json]"))
        XCTAssertTrue(CommandHelp(nouns: CommandNoun.all).entries.first { $0.command == "openspot help" }?.about.contains("its page of the guide, when it has one.") == true)
        XCTAssertFalse(CommandLineCall.usage.hasSuffix("\n\n"))
    }

    func testASettingBelongsToTheSpotThatRunsTheCommand() {
        let spot = ["OPENSPOT_ID": "repos"]

        XCTAssertEqual(CommandLineCall(arguments: ["setting", "get", "folder"], environment: spot)?.value as? SettingCall, .get(spot: "repos", key: "folder"))
        XCTAssertEqual(CommandLineCall(arguments: ["setting", "set", "folder", "/a b"], environment: spot)?.value as? SettingCall, .set(spot: "repos", key: "folder", value: "/a b"))
        XCTAssertEqual(CommandLineCall(arguments: ["setting", "set", "folder"], environment: spot)?.value as? SettingCall, .set(spot: "repos", key: "folder", value: nil))
        XCTAssertEqual(CommandLineCall(arguments: ["setting", "get", "--spot", "home/coffee", "size"], environment: spot)?.value as? SettingCall, .get(spot: "home/coffee", key: "size"))
        XCTAssertEqual(CommandLineCall(arguments: ["setting", "get"], environment: spot)?.value as? CallFault, .unknown(["setting", "get"]))
        XCTAssertEqual(CommandLineCall(arguments: ["setting", "set", "a", "b", "c"], environment: spot)?.value as? CallFault, .unknown(["setting", "set", "a", "b", "c"]))
    }

    func testASettingWithNoSpotIsRefused() {
        XCTAssertEqual(
            CommandLineCall(arguments: ["setting", "get", "folder"], environment: [:])?.value as? CallFault, .refused("`openspot setting` needs a spot. Run it from a spot, or name one with `--spot <id>`."))
        XCTAssertEqual(CommandLineCall(arguments: ["setting", "get", "folder"], spot: "")?.value as? CallFault, .refused("`openspot setting` needs a spot. Run it from a spot, or name one with `--spot <id>`."))
    }

    func testACommandThatWaitsForThePersonIsRefusedInARead() {
        XCTAssertEqual(CommandLineCall(arguments: ["folder", "pick"], environment: [:])?.value as? FolderCall, .pick)
        XCTAssertEqual(
            CommandLineCall(arguments: ["folder", "pick"], environment: [:], reason: "sheet")?.value as? CallFault, .refused("`openspot folder pick` waits for the person, so it cannot run in a show. Run it from a pick or an action."))
        XCTAssertEqual(
            CommandLineCall(arguments: ["color", "pick"], environment: [:], reason: "panel")?.value as? CallFault, .refused("`openspot color pick` waits for the person, so it cannot run in a show. Run it from a pick or an action."))
    }

    func testAWindowCallReadsItsFrames() {
        XCTAssertEqual(CommandLineCall(arguments: ["window", "frame"])?.value as? WindowCall, .frame)
        XCTAssertEqual(CommandLineCall(arguments: ["window", "move", "-1440", "25", "720", "900"])?.value as? WindowCall, .move(WindowMove(words: ["-1440", "25", "720", "900"])!))
        XCTAssertEqual(CommandLineCall(arguments: ["window", "move", "0 0 1/4 1", "0 0 1/3 1"])?.value as? WindowCall, .move(WindowMove(words: ["0", "0", "1/4", "1", "0", "0", "1/3", "1"])!))
        XCTAssertEqual(CommandLineCall(arguments: ["window", "move", "0", "25", "720"])?.value as? CallFault, .unknown(["window", "move", "0", "25", "720"]))
        XCTAssertEqual(CommandLineCall(arguments: ["window", "move", "0", "25", "wide", "900"])?.value as? CallFault, .unknown(["window", "move", "0", "25", "wide", "900"]))
        XCTAssertEqual(CommandLineCall(arguments: ["window", "move", "0", "25", "0", "900"])?.value as? CallFault, .unknown(["window", "move", "0", "25", "0", "900"]))
        XCTAssertEqual(CommandLineCall(arguments: ["window", "move", "0", "0", "1/0", "1"])?.value as? CallFault, .unknown(["window", "move", "0", "0", "1/0", "1"]))
        XCTAssertEqual(CommandLineCall(arguments: ["window", "move", "0", "0", "50%%", "1"])?.value as? CallFault, .unknown(["window", "move", "0", "0", "50%%", "1"]))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot window move frame..."))
    }

    func testAScreenCallReadsItsWords() {
        XCTAssertEqual(CommandLineCall(arguments: ["screen", "sources"])?.value as? ScreenCall, .sources)
        XCTAssertEqual(CommandLineCall(arguments: ["screen", "shot"])?.value as? ScreenCall, .shot(ScreenCapture()))
        XCTAssertEqual(CommandLineCall(arguments: ["screen", "shot", "window:front", "a.png"])?.value as? ScreenCall, .shot(ScreenCapture(source: .window(.front), file: "a.png")))
        XCTAssertEqual(CommandLineCall(arguments: ["screen", "shot", "mic"])?.value as? CallFault, .unknown(["screen", "shot", "mic"]))
        XCTAssertEqual(CommandLineCall(arguments: ["screen", "sources", "all"])?.value as? CallFault, .unknown(["screen", "sources", "all"]))
        XCTAssertEqual(CommandLineCall(arguments: ["screen"])?.value as? CallFault, .unknown(["screen"]))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot screen sources"))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot screen shot"))
    }

    func testACallThatChangesTheMacOrThePlacesOfTheAppIsRefusedInARead() {
        let read: [String: String] = ["OPENSPOT_ID": "tools"]
        let refusals = [
            (["window", "move", "0 0 1 1"], "`openspot window move` moves a window"),
            (["clipboard", "copy", "hi"], "`openspot clipboard copy` changes the clipboard"),
            (["clipboard", "paste"], "`openspot clipboard paste` types in the front app"),
            (["spot", "open", "notes", "--select"], "`openspot spot open` opens the panel"),
            (["spot", "delete", "notes"], "`openspot spot delete` changes your spots folder"),
            (["setting", "set", "key.go", "ctrl+k"], "`openspot setting set key.go` sets a key of your Mac"),
            (["setting", "set", "float", "shake"], "`openspot setting set float` sets a key of your Mac"),
            (["setting", "set", "--spot", "openspot", "panel-key", "ctrl+space"], "`openspot setting set --spot openspot panel-key` sets a key of your Mac"),
            (["setting", "set", "--spot", "openspot", "fix-key", "ctrl+f"], "`openspot setting set --spot openspot fix-key` sets a key of your Mac"),
            (["setting", "set", "menubar", "true"], "`openspot setting set menubar` changes the menu bar"),
        ]
        for (arguments, act) in refusals {
            XCTAssertEqual(CommandLineCall(arguments: arguments, environment: read, reason: "panel.open")?.value as? CallFault, .refused("\(act), so it cannot run in a show. Run it from a pick or an action."), arguments.joined(separator: " "))
            XCTAssertNotEqual(CommandLineCall(arguments: arguments, environment: ["OPENSPOT_ID": "tools"])?.value as? CallFault, .refused("\(act), so it cannot run in a show. Run it from a pick or an action."))
        }
        XCTAssertEqual(CommandLineCall(arguments: ["clipboard", "read"], environment: read, reason: "panel.open")?.value as? ClipboardCall, .read(within: nil))
        XCTAssertEqual(CommandLineCall(arguments: ["window", "frame"], environment: read, reason: "panel.open")?.value as? WindowCall, .frame)
        XCTAssertEqual(CommandLineCall(arguments: ["setting", "set", "folder", "/tmp"], environment: read, reason: "panel.open")?.value as? SettingCall, .set(spot: "tools", key: "folder", value: "/tmp"))
    }

    func testAScreenCaptureIsRefusedInAReadAndTheSourcesAreNot() {
        let read: [String: String] = [:]

        XCTAssertEqual(CommandLineCall(arguments: ["screen", "sources"], environment: read, reason: "panel")?.value as? ScreenCall, .sources)
        XCTAssertEqual(
            CommandLineCall(arguments: ["screen", "shot", "display"], environment: read, reason: "panel")?.value as? CallFault, .refused("`openspot screen shot` captures the screen, so it cannot run in a show. Run it from a pick or an action."))
    }

    func testARecordingCallReadsItsWordsAndOnlyItsStatusRunsInARead() {
        let read: [String: String] = [:]

        XCTAssertEqual(CommandLineCall(arguments: ["screen", "record", "start", "display:1", "mic", "talk.mp4"])?.value as? ScreenCall, .recordStart(ScreenCapture(source: .display(1), inputs: [.mic(nil)], file: "talk.mp4")))
        XCTAssertEqual(CommandLineCall(arguments: ["screen", "record", "stop"])?.value as? ScreenCall, .recordStop)
        XCTAssertEqual(CommandLineCall(arguments: ["screen", "record", "status"], environment: read, reason: "timer")?.value as? ScreenCall, .recordStatus)
        XCTAssertEqual(CommandLineCall(arguments: ["screen", "record", "start", "mic", "mic"])?.value as? CallFault, .unknown(["screen", "record", "start", "mic", "mic"]))
        XCTAssertEqual(CommandLineCall(arguments: ["screen", "record", "stop", "now"])?.value as? CallFault, .unknown(["screen", "record", "stop", "now"]))
        XCTAssertEqual(CommandLineCall(arguments: ["screen", "record"])?.value as? CallFault, .unknown(["screen", "record"]))
        XCTAssertEqual(
            CommandLineCall(arguments: ["screen", "record", "start"], environment: read, reason: "timer")?.value as? CallFault, .refused("`openspot screen record start` captures the screen, so it cannot run in a show. Run it from a pick or an action."))
        XCTAssertEqual(
            CommandLineCall(arguments: ["screen", "record", "stop"], environment: read, reason: "timer")?.value as? CallFault, .refused("`openspot screen record stop` captures the screen, so it cannot run in a show. Run it from a pick or an action."))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot screen record start"))
    }

    func testACalendarCallReadsItsDaysAndHiddenCalendarsAndRunsInARead() {
        let read: [String: String] = [:]
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "events"], environment: read, reason: "panel")?.value as? CalendarCall, .events(days: 1, hidden: []))
        XCTAssertEqual(
            CommandLineCall(arguments: ["calendar", "events", "--days", "2", "--hide", "A8E2", "--hide", "B1"])?.value as? CalendarCall, .events(days: 2, hidden: ["A8E2", "B1"]))
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "calendars"], environment: read, reason: "panel")?.value as? CalendarCall, .calendars)
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "events", "--days", "0"])?.value as? CallFault, .unknown(["calendar", "events", "--days", "0"]))
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "events", "--days"])?.value as? CallFault, .unknown(["calendar", "events", "--days"]))
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "events", "today"])?.value as? CallFault, .unknown(["calendar", "events", "today"]))
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "events", "--calendar", "A8E2"])?.value as? CallFault, .unknown(["calendar", "events", "--calendar", "A8E2"]))
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "calendars", "all"])?.value as? CallFault, .unknown(["calendar", "calendars", "all"]))
        XCTAssertEqual(CommandLineCall(arguments: ["calendar"])?.value as? CallFault, .unknown(["calendar"]))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot calendar events"))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot calendar calendars"))
    }

    func testARemindersCallReadsItsWordsAndDoneIsRefusedInARead() {
        let read: [String: String] = [:]
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "due"], environment: read, reason: "panel")?.value as? RemindersCall, .due(days: 1, hidden: []))
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "due", "--days", "2", "--hide", "7D10"])?.value as? RemindersCall, .due(days: 2, hidden: ["7D10"]))
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "lists"], environment: read, reason: "panel")?.value as? RemindersCall, .lists)
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "done", "reminder:9C41"])?.value as? RemindersCall, .done(id: "reminder:9C41", isDone: true))
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "done", "reminder:9C41", "false"])?.value as? RemindersCall, .done(id: "reminder:9C41", isDone: false))
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "done", "reminder:9C41", "maybe"])?.value as? CallFault, .unknown(["reminders", "done", "reminder:9C41", "maybe"]))
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "done"])?.value as? CallFault, .unknown(["reminders", "done"]))
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "due", "--list", "7D10"])?.value as? CallFault, .unknown(["reminders", "due", "--list", "7D10"]))
        XCTAssertEqual(
            CommandLineCall(arguments: ["reminders", "done", "reminder:9C41"], environment: read, reason: "panel")?.value as? CallFault, .refused("`openspot reminders done` changes your reminders, so it cannot run in a show. Run it from a pick or an action."))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot reminders due"))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot reminders lists"))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot reminders done"))
    }

    func testAnAddJoinsItsWordsAndOnlyADryRunRunsInARead() {
        let read: [String: String] = [:]
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "add", "Lunch", "tomorrow", "13:00"])?.value as? CalendarCall, .add(words: "Lunch tomorrow 13:00", isDry: false))
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "add", "--dry-run", "Lunch tomorrow"], environment: read, reason: "search")?.value as? CalendarCall, .add(words: "Lunch tomorrow", isDry: true))
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "add", "Call mom"])?.value as? RemindersCall, .add(words: "Call mom", isDry: false))
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "add", "--dry-run", "Call", "mom"], environment: read, reason: "search")?.value as? RemindersCall, .add(words: "Call mom", isDry: true))
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "add"])?.value as? CallFault, .unknown(["reminders", "add"]))
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "add", "--dry-run"])?.value as? CallFault, .unknown(["calendar", "add", "--dry-run"]))
        XCTAssertEqual(
            CommandLineCall(arguments: ["calendar", "add", "Lunch"], environment: read, reason: "search")?.value as? CallFault, .refused("`openspot calendar add` changes your calendars, so it cannot run in a show. Run it from a pick or an action."))
        XCTAssertEqual(
            CommandLineCall(arguments: ["reminders", "add", "Call mom"], environment: read, reason: "search")?.value as? CallFault, .refused("`openspot reminders add` changes your reminders, so it cannot run in a show. Run it from a pick or an action."))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot calendar add"))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot reminders add"))
    }

    func testAShowTakesOneIdAndIsRefusedInARead() {
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "show", "event:3F2A/1794300000"])?.value as? CalendarCall, .show(id: "event:3F2A/1794300000"))
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "show"])?.value as? CallFault, .unknown(["calendar", "show"]))
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "show", "a", "b"])?.value as? CallFault, .unknown(["calendar", "show", "a", "b"]))
        XCTAssertEqual(
            CommandLineCall(arguments: ["calendar", "show", "reminder:9C41"], environment: [:], reason: "panel")?.value as? CallFault, .refused("`openspot calendar show` opens Calendar, so it cannot run in a show. Run it from a pick or an action."))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot calendar show"))
    }

    func testAReminderShowTakesOneIdAndIsRefusedInARead() {
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "show", "reminder:9C41"])?.value as? RemindersCall, .show(id: "reminder:9C41"))
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "show"])?.value as? CallFault, .unknown(["reminders", "show"]))
        XCTAssertEqual(
            CommandLineCall(arguments: ["reminders", "show", "reminder:9C41"], environment: [:], reason: "panel")?.value as? CallFault, .refused("`openspot reminders show` opens Reminders, so it cannot run in a show. Run it from a pick or an action."))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot reminders show"))
    }

    func testAnUnknownCallAsksForHelp() {
        XCTAssertEqual(CommandLineCall(arguments: ["paint"])?.value as? CallFault, .unknown(["paint"]))
        XCTAssertEqual(CommandLineCall(arguments: ["color", "mix"])?.value as? CallFault, .unknown(["color", "mix"]))
        XCTAssertEqual(CommandLineCall(arguments: ["translate", "text", "--to"])?.value as? CallFault, .unknown(["translate", "text", "--to"]))
    }

    func testAScriptFindsTheCommandOnItsPath() {
        let environment = ScriptProcess.environment(base: ["PATH": "/usr/bin", "HOME": "/h"], app: "/A/Openspot.app/Contents/MacOS/Openspot")

        XCTAssertEqual(environment["PATH"]?.hasPrefix("/A/Openspot.app/Contents/Helpers:/usr/bin:"), true)
        XCTAssertEqual(environment["HOME"], "/h")
    }

    func testEachHiddenSpellingIsGone() {
        for words in [["spot", "on", "x"], ["spot", "off", "x"], ["menubar", "on", "x"], ["key", "set", "x", "go", "ctrl+k"], ["app", "login", "on"], ["app", "link", "off"], ["app", "careful", "on"], ["sandbox"]] {
            XCTAssertEqual(CommandLineCall(arguments: words)?.value as? CallFault, .unknown(words))
        }
    }
}
