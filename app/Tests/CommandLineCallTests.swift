import XCTest
@testable import OpenspotCore

final class CommandLineCallTests: XCTestCase {
    func testACapabilityStartsItsHelperWithACallThatTheUsageDoesNotList() {
        XCTAssertEqual(CommandLineCall(arguments: ["helper", "translate"]), .helper("translate"))
        XCTAssertEqual(CommandLineCall(arguments: ["helper"]), .unknown("helper"))
        XCTAssertFalse(CommandLineCall.usage.contains("helper"))
    }

    func testTheAppDrawsAPictureBookWithAHelperCallThatTheUsageDoesNotList() {
        XCTAssertEqual(CommandLineCall(arguments: ["helper", "glyphs", "24", "19.2", "/tmp/book"]), .glyphBook(side: 24, fontSize: 19.2, path: "/tmp/book"))
        XCTAssertEqual(CommandLineCall(arguments: ["helper", "glyphs", "big", "19.2", "/tmp/book"]), .unknown("helper glyphs big 19.2 /tmp/book"))
        XCTAssertEqual(CommandLineCall(arguments: ["helper", "glyphs", "24"]), .unknown("helper glyphs 24"))
        XCTAssertFalse(CommandLineCall.usage.contains("glyphs"))
    }

    func testEventEmitTakesAnEventNameAndAValue() {
        XCTAssertEqual(CommandLineCall(arguments: ["event", "emit", "music.track"]), .eventEmit(name: "music.track", value: nil))
        XCTAssertEqual(CommandLineCall(arguments: ["event", "emit", "music.track", "Blue in Green"]), .eventEmit(name: "music.track", value: "Blue in Green"))
        XCTAssertEqual(CommandLineCall(arguments: ["event", "emit", "clipboard.change"], environment: ["OPENSPOT_REASON": "panel.open"]), .eventEmit(name: "clipboard.change", value: nil))
        XCTAssertEqual(CommandLineCall(arguments: ["event", "emit", "music.track"], environment: ["OPENSPOT_REASON": "music.track"]), .refused("`openspot event emit music.track` runs in a read of `music.track`, so it would read that spot again without end, and Openspot did not raise it. Raise it from an action, or raise another event."))
        XCTAssertEqual(CommandLineCall(arguments: ["event", "emit", "music.next"], environment: ["OPENSPOT_REASON": "music.track"]), .eventEmit(name: "music.next", value: nil))
        XCTAssertEqual(CommandLineCall(arguments: ["event", "emit", "music"]), .refused("`music` is not an event. Name one with a dot, such as `music.track`."))
        XCTAssertEqual(CommandLineCall(arguments: ["event", "emit"]), .unknown("event emit"))
        XCTAssertEqual(CommandLineCall(arguments: ["event", "emit", "a.b", "c", "d"]), .unknown("event emit a.b c d"))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot event emit <name> [value]"))
    }

    func testAccountPrintsItsFactsAndReachesTheKey() {
        XCTAssertEqual(CommandLineCall(arguments: ["account"]), .accountStatus(frame: false))
        XCTAssertEqual(CommandLineCall(arguments: ["account", "--frame"], environment: ["OPENSPOT_REASON": "sheet.open"]), .accountStatus(frame: true))
        XCTAssertEqual(CommandLineCall(arguments: ["account", "open"]), .unknown("account open"))
        XCTAssertEqual(CommandLineCall(arguments: ["account", "sync", "off"]), .accountSync(false))
        XCTAssertEqual(CommandLineCall(arguments: ["account", "sign-out"], environment: ["OPENSPOT_REASON": "sheet.open"]), .refused("`openspot account sign-out` changes your account, so it cannot run in a read. Run it from a pick or an action."))
        XCTAssertEqual(CommandLineCall(arguments: ["account", "words"], environment: ["OPENSPOT_REASON": "sheet.open"]), .accountWords)
        XCTAssertEqual(CommandLineCall(arguments: ["account", "check", "4", "13"]), .unknown("account check 4 13"))
        XCTAssertEqual(CommandLineCall(arguments: ["account", "sync", "maybe"]), .unknown("account sync maybe"))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot account words"))
    }

    func testEmojiCanNameATone() {
        XCTAssertEqual(CommandLineCall(arguments: ["emoji"]), .emoji(tone: .none))
        XCTAssertEqual(CommandLineCall(arguments: ["emoji", "--tone", "medium-dark"]), .emoji(tone: .mediumDark))
        XCTAssertEqual(CommandLineCall(arguments: ["emoji", "--tone", "blue"]), .unknown("emoji --tone blue"))
        XCTAssertEqual(CommandLineCall(arguments: ["emoji", "--tone"]), .unknown("emoji --tone"))
    }

    func testCalcSolvesTheWordsAfterItsVerbAlsoInARead() {
        XCTAssertEqual(CommandLineCall(arguments: ["calc", "solve", "2*(3+4)"]), .calcSolve("2*(3+4)"))
        XCTAssertEqual(CommandLineCall(arguments: ["calc", "solve", "5", "km", "in", "mi"]), .calcSolve("5 km in mi"))
        XCTAssertEqual(CommandLineCall(arguments: ["calc", "solve", "1+1"], environment: ["OPENSPOT_REASON": "search"]), .calcSolve("1+1"))
        XCTAssertEqual(CommandLineCall(arguments: ["calc", "solve"]), .unknown("calc solve"))
        XCTAssertEqual(CommandLineCall(arguments: ["calc", "2+2"]), .unknown("calc 2+2"))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot calc solve <words>..."))
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
        XCTAssertEqual(CommandLineCall(arguments: ["render", "--panel", "a.png"]), .renderPanel("a.png"))
        XCTAssertEqual(CommandLineCall(arguments: ["render"]), .unknown("render"))
    }

    func testTheSpotNounMakesRunsShowsAndLogsOneSpot() {
        XCTAssertEqual(CommandLineCall(arguments: ["guide"]), .guide)
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "new", "Weather"]), .spotNew(name: "Weather", starter: .button))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "new", "Weather", "--from", "list"]), .spotNew(name: "Weather", starter: .list))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "new", "Weather", "--from", "tree"]), .unknown("spot new Weather --from tree"))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "run", "weather"]), .spotRun(id: "weather", arguments: []))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "run", "weather", "open", "today"]), .spotRun(id: "weather", arguments: ["open", "today"]))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "show", "weather"]), .spotShow("weather"))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "log", "weather"]), .spotLog("weather"))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "stats"]), .spotStats(days: 1, spot: nil, format: .text))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "stats", "--days", "7", "--spot", "home/coffee", "--json"]), .spotStats(days: 7, spot: "home/coffee", format: .json))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "stats", "--frame"]), .spotStats(days: 1, spot: nil, format: .frame))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "stats", "--days", "1000000"]), .spotStats(days: 90, spot: nil, format: .text))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "stats", "weather"]), .unknown("spot stats weather"))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "stats", "--days", "0"]), .unknown("spot stats --days 0"))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "stats", "--frame", "--json"]), .unknown("spot stats --frame --json"))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot spot stats"))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "show"]), .unknown("spot show"))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot spot run"))
    }

    func testACheckCanPrintJSONAndARenderCanNameAnInstalledSpot() {
        XCTAssertEqual(CommandLineCall(arguments: ["check", "--json"]), .checkJSON(nil))
        XCTAssertEqual(CommandLineCall(arguments: ["check", "--json", "spots"]), .checkJSON("spots"))
        XCTAssertEqual(CommandLineCall(arguments: ["render", "--spot", "weather", "a.png"]), .renderSpot(id: "weather", size: nil, path: "a.png"))
        XCTAssertEqual(CommandLineCall(arguments: ["render", "--spot", "weather", "--card", "wide", "a.png"]), .renderSpot(id: "weather", size: .wide, path: "a.png"))
        XCTAssertEqual(CommandLineCall(arguments: ["render", "--spot", "weather", "--card", "huge", "a.png"]), .unknown("render --spot weather --card huge a.png"))
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
        XCTAssertEqual(CommandLineCall(arguments: ["color", "pick"]), .colorPick)
        XCTAssertEqual(CommandLineCall(arguments: ["clipboard", "copy", "/a b.mov"]), .clipboardCopy("/a b.mov"))
        XCTAssertEqual(CommandLineCall(arguments: ["clipboard", "paste"]), .clipboardPaste)
        XCTAssertEqual(CommandLineCall(arguments: ["clipboard", "copy"]), .clipboardCopy(nil))
        XCTAssertEqual(CommandLineCall(arguments: ["clipboard", "read"]), .clipboardRead)
        XCTAssertEqual(CommandLineCall(arguments: ["translate", "languages"]), .translateLanguages)
        XCTAssertEqual(CommandLineCall(arguments: ["translate"]), .translate(from: nil, to: nil))
        XCTAssertEqual(CommandLineCall(arguments: ["translate", "--from", "ru", "--to", "en"]), .translate(from: "ru", to: "en"))
        XCTAssertEqual(CommandLineCall(arguments: ["translate", "--from", "auto", "--to", "en"]), .translate(from: nil, to: "en"))
        XCTAssertEqual(CommandLineCall(arguments: ["--help"]), .help)
    }

    func testHelpCanNameTheNounWhoseGuideItPrints() {
        XCTAssertEqual(CommandLineCall(arguments: ["help"]), .help)
        XCTAssertEqual(CommandLineCall(arguments: ["help", "screen"]), .guideOf("screen"))
        XCTAssertEqual(CommandLineCall(arguments: ["help", "reminders"]), .guideOf("reminders"))
        XCTAssertEqual(CommandLineCall(arguments: ["help", "screen", "shot"]), .unknown("help screen shot"))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot help [noun]"))
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

    func testACallThatChangesTheMacOrThePlacesOfTheAppIsRefusedInARead() {
        let read = ["OPENSPOT_REASON": "panel.open", "OPENSPOT_ID": "tools"]
        let refusals = [
            (["window", "move", "0 0 1 1"], "`openspot window move` moves a window"),
            (["clipboard", "copy", "hi"], "`openspot clipboard copy` changes the clipboard"),
            (["clipboard", "paste"], "`openspot clipboard paste` types in the front app"),
            (["spot", "show", "notes"], "`openspot spot show` opens the panel"),
            (["setting", "set", "key.go", "ctrl+k"], "`openspot setting set key.go` sets a key of your Mac"),
            (["setting", "set", "float", "shake"], "`openspot setting set float` sets a key of your Mac"),
            (["setting", "set", "--spot", "openspot", "panel-key", "ctrl+space"], "`openspot setting set --spot openspot panel-key` sets a key of your Mac"),
            (["setting", "set", "--spot", "openspot", "fix-key", "ctrl+f"], "`openspot setting set --spot openspot fix-key` sets a key of your Mac"),
            (["setting", "set", "menubar", "true"], "`openspot setting set menubar` changes the menu bar"),
            (["setting", "set", "enabled", "false"], "`openspot setting set enabled` turns a spot on or off"),
        ]
        for (arguments, act) in refusals {
            XCTAssertEqual(CommandLineCall(arguments: arguments, environment: read), .refused("\(act), so it cannot run in a read. Run it from a pick or an action."), arguments.joined(separator: " "))
            XCTAssertNotEqual(CommandLineCall(arguments: arguments, environment: ["OPENSPOT_ID": "tools"]), .refused("\(act), so it cannot run in a read. Run it from a pick or an action."))
        }
        XCTAssertEqual(CommandLineCall(arguments: ["clipboard", "read"], environment: read), .clipboardRead)
        XCTAssertEqual(CommandLineCall(arguments: ["window", "frame"], environment: read), .windowFrame)
        XCTAssertEqual(CommandLineCall(arguments: ["setting", "set", "folder", "/tmp"], environment: read), .settingSet(spot: "tools", key: "folder", value: "/tmp"))
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

    func testACalendarCallReadsItsDaysAndHiddenCalendarsAndRunsInARead() {
        let read = ["OPENSPOT_REASON": "panel"]
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "events"], environment: read), .calendarEvents(days: 1, hidden: []))
        XCTAssertEqual(
            CommandLineCall(arguments: ["calendar", "events", "--days", "2", "--hide", "A8E2", "--hide", "B1"]),
            .calendarEvents(days: 2, hidden: ["A8E2", "B1"])
        )
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "calendars"], environment: read), .calendarCalendars)
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "events", "--days", "0"]), .unknown("calendar events --days 0"))
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "events", "--days"]), .unknown("calendar events --days"))
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "events", "today"]), .unknown("calendar events today"))
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "events", "--calendar", "A8E2"]), .unknown("calendar events --calendar A8E2"))
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "calendars", "all"]), .unknown("calendar calendars all"))
        XCTAssertEqual(CommandLineCall(arguments: ["calendar"]), .unknown("calendar"))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot calendar events"))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot calendar calendars"))
    }

    func testARemindersCallReadsItsWordsAndDoneIsRefusedInARead() {
        let read = ["OPENSPOT_REASON": "panel"]
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "due"], environment: read), .remindersDue(days: 1, hidden: []))
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "due", "--days", "2", "--hide", "7D10"]), .remindersDue(days: 2, hidden: ["7D10"]))
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "lists"], environment: read), .remindersLists)
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "done", "reminder:9C41"]), .remindersDone(id: "reminder:9C41", isDone: true))
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "done", "reminder:9C41", "false"]), .remindersDone(id: "reminder:9C41", isDone: false))
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "done", "reminder:9C41", "maybe"]), .unknown("reminders done reminder:9C41 maybe"))
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "done"]), .unknown("reminders done"))
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "due", "--list", "7D10"]), .unknown("reminders due --list 7D10"))
        XCTAssertEqual(
            CommandLineCall(arguments: ["reminders", "done", "reminder:9C41"], environment: read),
            .refused("`openspot reminders done` changes your reminders, so it cannot run in a read. Run it from a pick or an action.")
        )
        XCTAssertTrue(CommandLineCall.usage.contains("openspot reminders due"))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot reminders lists"))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot reminders done"))
    }

    func testAnAddJoinsItsWordsAndOnlyADryRunRunsInARead() {
        let read = ["OPENSPOT_REASON": "search"]
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "add", "Lunch", "tomorrow", "13:00"]), .calendarAdd(words: "Lunch tomorrow 13:00", isDry: false))
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "add", "--dry-run", "Lunch tomorrow"], environment: read), .calendarAdd(words: "Lunch tomorrow", isDry: true))
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "add", "Call mom"]), .remindersAdd(words: "Call mom", isDry: false))
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "add", "--dry-run", "Call", "mom"], environment: read), .remindersAdd(words: "Call mom", isDry: true))
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "add"]), .unknown("reminders add"))
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "add", "--dry-run"]), .unknown("calendar add --dry-run"))
        XCTAssertEqual(
            CommandLineCall(arguments: ["calendar", "add", "Lunch"], environment: read),
            .refused("`openspot calendar add` changes your calendars, so it cannot run in a read. Run it from a pick or an action.")
        )
        XCTAssertEqual(
            CommandLineCall(arguments: ["reminders", "add", "Call mom"], environment: read),
            .refused("`openspot reminders add` changes your reminders, so it cannot run in a read. Run it from a pick or an action.")
        )
        XCTAssertTrue(CommandLineCall.usage.contains("openspot calendar add"))
        XCTAssertTrue(CommandLineCall.usage.contains("openspot reminders add"))
    }

    func testAShowTakesOneIdAndIsRefusedInARead() {
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "show", "event:3F2A/1794300000"]), .calendarShow(id: "event:3F2A/1794300000"))
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "show"]), .unknown("calendar show"))
        XCTAssertEqual(CommandLineCall(arguments: ["calendar", "show", "a", "b"]), .unknown("calendar show a b"))
        XCTAssertEqual(
            CommandLineCall(arguments: ["calendar", "show", "reminder:9C41"], environment: ["OPENSPOT_REASON": "panel"]),
            .refused("`openspot calendar show` opens Calendar, so it cannot run in a read. Run it from a pick or an action.")
        )
        XCTAssertTrue(CommandLineCall.usage.contains("openspot calendar show"))
    }

    func testAReminderShowTakesOneIdAndIsRefusedInARead() {
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "show", "reminder:9C41"]), .remindersShow(id: "reminder:9C41"))
        XCTAssertEqual(CommandLineCall(arguments: ["reminders", "show"]), .unknown("reminders show"))
        XCTAssertEqual(
            CommandLineCall(arguments: ["reminders", "show", "reminder:9C41"], environment: ["OPENSPOT_REASON": "panel"]),
            .refused("`openspot reminders show` opens Reminders, so it cannot run in a read. Run it from a pick or an action.")
        )
        XCTAssertTrue(CommandLineCall.usage.contains("openspot reminders show"))
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
