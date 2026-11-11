import Foundation

/// What the `openspot` command was asked to do: `openspot <noun> <verb>`. No arguments start the app.
public enum CommandLineCall: Equatable, Sendable {
    case check(String?)
    /// Reports the faults of a plugins folder as JSON, for an agent.
    case checkJSON(String?)
    case guide
    /// Writes a working spot from a starter, with a name.
    case spotNew(name: String, starter: SpotStarter)
    /// Makes one call of a spot as the app makes it.
    case spotRun(id: String, arguments: [String])
    /// Asks the running app to show the panel with the spot selected.
    case spotShow(String)
    /// Prints the record of the last calls of a spot.
    case spotLog(String)
    /// Prints what each spot cost and used over the last days, for one spot or each one (Z10).
    case spotStats(days: Int, spot: String?, format: StatsReport.Format)
    /// Prints each script that the app loads as JSON, or with `core` each spot that comes with the app, and with `frame` as
    /// `key=value` blocks (K8).
    case spotList(core: Bool, frame: Bool)
    /// Turns spots that come with the app on or off.
    case spotTurn(ids: [String], on: Bool)
    /// Puts a spot from a git URL, a folder or a `.spot` file in the plugins folder, or with none each spot of `spots.lock`
    /// that is missing (N1, N2). An update that adds a use applies only when it is confirmed (Z7).
    case spotAdd(String?, isConfirmed: Bool)
    /// Takes a spot that `spot add` added out of the plugins folder.
    case spotRemove(String)
    /// Opens the panel on the sheet of a spot.
    case spotOpen(String)
    /// Shows the whole text of a spot that comes with the app.
    case spotReview(String)
    /// Runs the action of a spot's setting in the panel, as Enter on its row in Settings does.
    case settingChange(spot: String, key: String)
    /// Prints the prompt that asks a coding agent to build a spot that does what the words say.
    case promptNew(String)
    /// Draws the sheet of an installed spot, or its card at a size.
    case renderSpot(id: String, size: SpotSize?, path: String)
    case checkSheet
    /// Draws the sheet on stdin, with the plugin's view from a Swift file when it names one.
    case render(String, view: String?)
    /// Draws the card of the output on stdin at a size, from its drawing for that size.
    case renderCard(SpotSize, String)
    case sandbox(String?)
    case colorPick
    case folderPick
    /// Prints the value of a spot's setting, or nothing when it has none (K6).
    case settingGet(spot: String, key: String)
    /// Keeps the value of a spot's setting, or removes it with no value (K6).
    case settingSet(spot: String, key: String, value: String?)
    /// Prints each value that a spot keeps, as JSON.
    case settingList(frame: Bool)
    /// Runs one call for each line of stdin, and prints the output of each with a line `---` after it (K7).
    case batch
    /// Gives the app a key of its own: `panel_key` opens the panel, and `fix_key` opens the fix of a failure.
    case appKeySet(name: String, key: String)
    /// Gives a command, or the float of a spot, a key or the shake, or takes its key away with none (W1, W2).
    case keySet(spot: String, act: GlobalKey.Act, key: String?)
    /// Puts a spot in the menu bar, or takes it out.
    case menuBar(id: String, isShown: Bool)
    /// Prints the state of the app as JSON: its version, its keys, its login and terminal settings, and its update.
    case appStatus(frame: Bool)
    /// Opens the app at login, or stops it.
    case appLogin(Bool)
    /// Puts `openspot` on the path of a terminal, or takes it off.
    case appLink(Bool)
    /// Turns Careful mode on or off (Z8).
    case appCareful(Bool)
    case appQuit
    case updateCheck
    /// Restarts the app into the downloaded update.
    case updateInstall
    /// A call that cannot run here, with the line that says why and how to fix it.
    case refused(String)
    /// Copies a file, or the text on stdin with no file.
    case clipboardCopy(String?)
    case clipboardPaste
    /// Raises an event in the running app, with a value, so that each spot that lists it reads (B3).
    case eventEmit(name: String, value: String?)
    case translate(from: String?, to: String?)
    case translateLanguages
    /// Prints the answer of a sum or a conversion as one row, or nothing for words that are not one.
    case calcSolve(String)
    case emoji(tone: EmojiCatalog.Tone)
    case symbols
    case windowFrame
    case windowMove(WindowMove)
    case screenSources
    /// Takes a picture of a source, picked by the person when the words fix none (S1).
    case screenShot(ScreenCapture)
    /// Starts a recording in the helper of the screen, which goes on until a stop (S10).
    case screenRecordStart(ScreenCapture)
    case screenRecordStop
    case screenRecordStatus
    /// Prints the events that have not ended through the end of a day, in each calendar but the hidden ones (E1).
    case calendarEvents(days: Int, hidden: [String])
    case calendarCalendars
    /// Adds an event from the words, or with a dry run prints the row that it would add (E4, E5).
    case calendarAdd(words: String, isDry: Bool)
    /// Opens Calendar on the day of the event whose row has this id (E1).
    case calendarShow(id: String)
    /// Prints the open reminders that are late or due through the end of a day, and those done today, in each list but the
    /// hidden ones.
    case remindersDue(days: Int, hidden: [String])
    case remindersLists
    /// Adds a reminder from the words, or with a dry run prints the row that it would add (E4, E5).
    case remindersAdd(words: String, isDry: Bool)
    /// Ticks a reminder, or opens it again (E3).
    case remindersDone(id: String, isDone: Bool)
    /// Opens Reminders on the reminder whose row has this id (E1).
    case remindersShow(id: String)
    /// Runs as the helper process of a capability. A script never makes this call, so the usage does not list it.
    case helper(String)
    /// Draws the colour glyphs on stdin, one on each line, into a picture book at a path. Only the app makes this call.
    case glyphBook(side: Double, fontSize: Double, path: String)
    case help
    /// Prints the guide of a noun, such as `screen`.
    case guideOf(String)
    case unknown(String)

    public static let usage = """
    openspot guide                               Prints the guide to building a spot. Read it before you write one.
    openspot help [noun]                         Prints this list, or the guide of a noun: calendar, reminders or screen.
    openspot spot new <name> [--from kind]       Writes a working spot to change. A kind is button, list, number or form.
    openspot spot run <id> [call] [value]...     Makes one call of a spot as the app does, and prints all that it prints.
    openspot spot log <id>                       Prints the last calls that the app made to a spot.
    openspot spot stats [--days n] [--spot id] [--frame|--json]
                                                 Prints what each spot cost and used today, or over the last n days:
                                                 its runs, failures, CPU time, disk bytes, wakeups, each use of a power
                                                 and its last fault, then each use of a power. --frame prints a row for
                                                 each spot and a power block for each use; --json prints the days.
    openspot spot show <id>                      Opens the panel with the spot selected.
    openspot spot list [--core] [--frame]        Prints each spot that the app loads as JSON, with its commands, its
                                                 settings and their keys. --core prints each spot that comes with the
                                                 app, and whether it is on. --frame prints a spot=<id> block for each
                                                 spot, with a command=<id> or setting=<id> block for each of its own.
    openspot spot on|off <id>...                 Turns spots that come with the app on or off.
    openspot spot add [git url | folder | file.spot] [--yes]
                                                 Puts a spot in the plugins folder, a git one at its newest commit, and
                                                 records it in spots.lock. A source that spots.lock has already updates
                                                 its spot. With no source, it adds each spot of spots.lock that is
                                                 missing, at its commit. An update that adds a use needs --yes.
    openspot spot remove <id>                    Moves a spot that spot add added to the Trash, and drops it from spots.lock.
    openspot spot open <id>                      Opens the panel on the sheet of a spot.
    openspot spot review <id>                    Shows the whole text of a spot that comes with the app, and what of it
                                                 runs by itself.
    openspot check [--json] [folder]             Reports the faults of a plugins folder.
    openspot check --sheet                       Reports the faults of a sheet on stdin.
    openspot render [--view file] <file.png>     Draws the sheet on stdin to a picture, with its view from a Swift file.
    openspot render --card <size> <file.png>     Draws its card at a size, such as wide, to a picture.
    openspot render --spot <id> [--card <size>] <file.png>
                                                 Draws the sheet of an installed spot, or its card at a size.
    openspot sandbox [file]                      Opens a window to try a sheet from text, a file or a script.
    openspot color pick                          Prints the colour the person picks.
    openspot folder pick                         Prints the folder the person picks, or nothing after Cancel.
    openspot setting get [--spot id] <key>       Prints the value the person chose for the spot, or nothing.
    openspot setting set [--spot id] <key> [v]   Keeps a value for the spot, or removes it with no value.
    openspot setting list [--frame]              Prints each value that a spot keeps as JSON, with its spot and key.
                                                 --frame prints a setting=<key> block with spot and value for each.
    openspot setting change [--spot id] <key>    Runs the action of the setting in the panel, which can ask with a form.
    openspot prompt new <words>...               Prints a prompt that asks a coding agent to build a spot that does
                                                 what the words say.
    openspot key set --panel|--fix <key>         Gives the key that opens the panel, or the one that opens a fix.
    openspot key set <id> <command>|--float [key]
                                                 Gives a command of a spot, or its float, a key such as ctrl+option+k,
                                                 or shake. With no key, it takes the key away.
    openspot menubar on|off <id>                 Puts a spot in the menu bar, or takes it out.
    openspot app status [--frame]                Prints the state of the app as JSON: version, panelKey, fixKey, login,
                                                 link, update, calls and firstLaunch. --frame prints them as one block.
    openspot batch                               Runs one call for each line of stdin, its words split at spaces, and
                                                 prints the output of each with a line --- after it. It stops at the first
                                                 call that fails, and takes only a call that the app answers.
    openspot app login on|off                    Opens the app at login, or stops it.
    openspot app link on|off                     Puts openspot on the path of Terminal, or takes it off.
    openspot app careful on|off                  Runs each spot with only what its uses name, or as you.
    openspot app quit                            Ends the running app.
    openspot update check                        Asks for a new version of the app now.
    openspot update install                      Restarts the app into the update that it downloaded.
    openspot clipboard copy [file]               Copies the file as Finder does, or the text on stdin.
    openspot clipboard paste                     Pastes the clipboard into the front app.
    openspot event emit <name> [value]           Raises an event in the running app, such as music.track. Each spot
                                                 that lists it in its read reads, with the value in OPENSPOT_VALUE.
    openspot translate [--from code] [--to code] Translates the text on stdin.
    openspot translate languages                 Prints the languages it knows.
    openspot calc solve <words>...               Prints the answer of a sum, such as 2*(3+4) or 15% of 80, a conversion,
                                                 such as 5 km in mi or 15 usd in eur, or a date, such as today + 3 weeks,
                                                 days until 25 dec or 3pm tokyo in kyiv, as a row. It prints nothing for
                                                 words that are none. A currency with no rates prints status=offline with
                                                 no internet, or status=unavailable when the source does not answer.
                                                 Rates 3 days old or more say their age, with tone=warn. The row's id is
                                                 the plain value. Rates come from exchange-api, a public-domain file
                                                 that changes once a day.
    openspot emoji [--tone name]                 Prints each emoji as a row, with its name in the language of the Mac.
                                                 A tone is none, light, medium-light, medium, medium-dark or dark.
    openspot symbols                             Prints each symbol of the Character Viewer as a row, with its name and section.
    openspot window frame                        Prints the front window, then the usable area of its screen:
                                                 x y width height x y width height, from the top left of the main screen.
    openspot window move frame...                Moves the front window to a frame, x y width height. 50%, 1/2 or a number
                                                 from 0 to 1 is a part of the area, and any other number is points. With
                                                 more frames, it moves to the frame after the one it holds now.
    openspot screen sources                      Prints each display, window, microphone and camera as a row, with
                                                 its source as the id: display:<id>, window:<id>, mic:<id>, camera:<id>.
    openspot screen shot [source] [--cursor] [file]
                                                 Takes a picture and prints its path. A source is display, window,
                                                 window:front or area:x,y,w,h; with no value the person picks one, and
                                                 with no source any. With no file, it goes where macOS keeps screenshots.
    openspot screen record start [source] [input]... [--cursor] [--events file] [file]
                                                 Starts a recording to .mp4 or .mov. An input is mic, system or camera,
                                                 or mic:<id> or camera:<id>; the camera goes to its own file beside it.
                                                 --events writes each pointer move, click and key as a JSON line.
    openspot screen record stop                  Ends the recording and prints each file, the video first.
    openspot screen record status                Prints state=recording with its files and seconds, or state=idle.
    openspot calendar events [--days n] [--hide id]...
                                                 Prints each event that has not ended through the end of day n as a
                                                 row. Day 1, the default, is today. --hide leaves out a calendar.
    openspot calendar calendars                  Prints each calendar as a row.
    openspot calendar add [--dry-run] <words>... Adds an event from words such as Lunch tomorrow 13:00, and prints its
                                                 row. --dry-run prints the row and adds nothing.
    openspot calendar show <id>                  Opens Calendar on the day of the event of a row.
    openspot reminders due [--days n] [--hide id]...
                                                 Prints each open reminder that is late or due through the end of day n,
                                                 and each one done today, as a row. --hide leaves out a list.
    openspot reminders lists                     Prints each list of reminders as a row.
    openspot reminders add [--dry-run] <words>...
                                                 Adds a reminder from words such as Call mom tomorrow 9am, and prints its
                                                 row. --dry-run prints the row and adds nothing.
    openspot reminders done <id> [true|false]    Ticks a reminder, or with false opens it again.
    openspot reminders show <id>                 Opens Reminders on the reminder of a row.

    """

    private static let spotWord = "--spot"

    /// Whether the words are flags of this set, each at most once.
    private static func flags(_ words: ArraySlice<String>, within allowed: Set<String>) -> Bool {
        Set(words).count == words.count && Set(words).isSubset(of: allowed)
    }

    /// Returns nil when these arguments start the app, such as none or the flags that the system passes. The environment
    /// names the spot of a setting and tells a read, in which a command that waits for the person is refused (K4).
    public init?(arguments: [String], environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let noun = arguments.first else { return nil }
        if noun == "--help" || noun == "help" {
            switch arguments.count {
            case 1: self = .help
            case 2 where noun == "help": self = .guideOf(arguments[1])
            default: self = .unknown(arguments.joined(separator: " "))
            }
            return
        }
        guard !noun.hasPrefix("-") else { return nil }
        if arguments == ["check", "--sheet"] {
            self = .checkSheet
            return
        }
        let rest = Array(arguments.dropFirst())
        switch (noun, rest.first) {
        case ("guide", nil): self = .guide
        case ("check", "--json") where rest.count <= 2: self = .checkJSON(rest.dropFirst().first)
        case ("check", _) where rest.count <= 1: self = .check(rest.first)
        case ("spot", "new") where rest.count == 2: self = .spotNew(name: rest[1], starter: .button)
        case ("spot", "new") where rest.count == 4 && rest[2] == "--from":
            guard let starter = SpotStarter(rawValue: rest[3]) else { self = .unknown(arguments.joined(separator: " ")); return }
            self = .spotNew(name: rest[1], starter: starter)
        case ("spot", "run") where rest.count >= 2: self = .spotRun(id: rest[1], arguments: Array(rest.dropFirst(2)))
        case ("spot", "show") where rest.count == 2: self = .spotShow(rest[1])
        case ("spot", "log") where rest.count == 2: self = .spotLog(rest[1])
        case ("spot", "stats"): self = Self.stats(Array(rest.dropFirst())) ?? .unknown(arguments.joined(separator: " "))
        case ("spot", "list") where Self.flags(rest.dropFirst(), within: ["--core", "--frame"]):
            self = .spotList(core: rest.contains("--core"), frame: rest.contains("--frame"))
        case ("spot", "on") where rest.count > 1, ("spot", "off") where rest.count > 1:
            self = .spotTurn(ids: Array(rest.dropFirst()), on: rest[0] == "on")
        case ("spot", "add") where rest.dropFirst().filter({ $0 != "--yes" }).count <= 1 && rest.filter({ $0 == "--yes" }).count <= 1:
            self = Self.changing(.spotAdd(rest.dropFirst().first { $0 != "--yes" }, isConfirmed: rest.contains("--yes")), "openspot spot add", "changes your plugins folder", environment)
        case ("spot", "remove") where rest.count == 2: self = Self.changing(.spotRemove(rest[1]), "openspot spot remove", "changes your plugins folder", environment)
        case ("setting", "list") where Self.flags(rest.dropFirst(), within: ["--frame"]): self = .settingList(frame: rest.contains("--frame"))
        case ("setting", "change"):
            self = Self.setting(Array(rest.dropFirst()), sets: false, environment).map { call in
                guard case .settingGet(let spot, let key) = call else { return call }
                return Self.changing(.settingChange(spot: spot, key: key), "openspot setting change", "opens a form", environment)
            } ?? .unknown(arguments.joined(separator: " "))
        case ("spot", "open") where rest.count == 2: self = Self.changing(.spotOpen(rest[1]), "openspot spot open", "opens the panel", environment)
        case ("spot", "review") where rest.count == 2: self = Self.changing(.spotReview(rest[1]), "openspot spot review", "opens the panel", environment)
        case ("prompt", "new") where rest.count > 1: self = .promptNew(rest.dropFirst().joined(separator: " "))
        case ("key", "set"): self = Self.key(Array(rest.dropFirst())) ?? .unknown(arguments.joined(separator: " "))
        case ("app", "status") where Self.flags(rest.dropFirst(), within: ["--frame"]): self = .appStatus(frame: rest.contains("--frame"))
        case ("batch", nil): self = .batch
        case ("app", "login") where rest == ["login", "on"] || rest == ["login", "off"]:
            self = Self.changing(.appLogin(rest[1] == "on"), "openspot app login", "changes your Mac", environment)
        case ("app", "careful") where rest == ["careful", "on"] || rest == ["careful", "off"]:
            self = Self.changing(.appCareful(rest[1] == "on"), "openspot app careful", "changes how spots run", environment)
        case ("app", "link") where rest == ["link", "on"] || rest == ["link", "off"]:
            self = Self.changing(.appLink(rest[1] == "on"), "openspot app link", "changes your Mac", environment)
        case ("app", "quit") where rest.count == 1: self = Self.changing(.appQuit, "openspot app quit", "ends Openspot", environment)
        case ("update", "check") where rest.count == 1: self = Self.changing(.updateCheck, "openspot update check", "opens a window", environment)
        case ("update", "install") where rest.count == 1: self = Self.changing(.updateInstall, "openspot update install", "restarts Openspot", environment)
        case ("menubar", "on") where rest.count == 2, ("menubar", "off") where rest.count == 2:
            self = .menuBar(id: rest[1], isShown: rest[0] == "on")
        case ("render", "--spot") where rest.count == 3: self = .renderSpot(id: rest[1], size: nil, path: rest[2])
        case ("render", "--spot") where rest.count == 5 && rest[2] == "--card":
            guard let size = SpotSize(name: rest[3]) else { self = .unknown(arguments.joined(separator: " ")); return }
            self = .renderSpot(id: rest[1], size: size, path: rest[4])
        case ("sandbox", _) where rest.count <= 1: self = .sandbox(rest.first)
        case ("render", "--card") where rest.count == 3:
            guard let size = SpotSize(name: rest[1]) else { self = .unknown(arguments.joined(separator: " ")); return }
            self = .renderCard(size, rest[2])
        case ("render", "--view") where rest.count == 3: self = .render(rest[2], view: rest[1])
        case ("render", let path?) where rest.count == 1: self = .render(path, view: nil)
        case ("screen", "sources") where rest.count == 1: self = .screenSources
        case ("screen", "shot"):
            guard let capture = ScreenCapture(words: Array(rest.dropFirst()), records: false) else {
                self = .unknown(arguments.joined(separator: " "))
                return
            }
            self = Self.capturing(.screenShot(capture), "openspot screen shot", environment)
        case ("screen", "record") where rest.count >= 2:
            self = Self.recording(Array(rest.dropFirst(2)), verb: rest[1], environment) ?? .unknown(arguments.joined(separator: " "))
        case ("color", "pick") where rest.count == 1: self = Self.waiting(.colorPick, "openspot color pick", environment)
        case ("folder", "pick") where rest.count == 1: self = Self.waiting(.folderPick, "openspot folder pick", environment)
        case ("setting", "get"), ("setting", "set"):
            self = Self.setting(Array(rest.dropFirst()), sets: rest.first == "set", environment) ?? .unknown(arguments.joined(separator: " "))
        case ("clipboard", "copy") where rest.count <= 2: self = .clipboardCopy(rest.dropFirst().first)
        case ("clipboard", "paste") where rest.count == 1: self = .clipboardPaste
        case ("event", "emit") where rest.count == 2 || rest.count == 3:
            self = SpotEvent.isName(rest[1])
                ? .eventEmit(name: rest[1], value: rest.count == 3 ? rest[2] : nil)
                : .refused("`\(rest[1])` is not an event. Name one with a dot, such as `music.track`, or `clipboard`.")
        case ("translate", "languages") where rest.count == 1: self = .translateLanguages
        case ("calc", "solve") where rest.count > 1: self = .calcSolve(rest.dropFirst().joined(separator: " "))
        case ("helper", let name?) where rest.count == 1: self = .helper(name)
        case ("helper", "glyphs") where rest.count == 4:
            guard let side = Double(rest[1]), let fontSize = Double(rest[2]) else {
                self = .unknown(arguments.joined(separator: " "))
                return
            }
            self = .glyphBook(side: side, fontSize: fontSize, path: rest[3])
        case ("emoji", nil): self = .emoji(tone: .none)
        case ("symbols", nil): self = .symbols
        case ("emoji", "--tone") where rest.count == 2:
            guard let tone = EmojiCatalog.Tone(rawValue: rest[1]) else {
                self = .unknown(arguments.joined(separator: " "))
                return
            }
            self = .emoji(tone: tone)
        case ("window", "frame") where rest.count == 1: self = .windowFrame
        case ("window", "move") where rest.count > 1:
            guard let move = WindowMove(words: Array(rest.dropFirst())) else {
                self = .unknown(arguments.joined(separator: " "))
                return
            }
            self = .windowMove(move)
        case ("calendar", "events"):
            self = Self.listing(Array(rest.dropFirst())).map { .calendarEvents(days: $0.days, hidden: $0.hidden) }
                ?? .unknown(arguments.joined(separator: " "))
        case ("calendar", "calendars") where rest.count == 1: self = .calendarCalendars
        case ("calendar", "add"):
            self = Self.adding(Array(rest.dropFirst()), environment) { .calendarAdd(words: $0, isDry: $1) }
                .map { Self.changing($0, "openspot calendar add", "changes your calendars", environment) } ?? .unknown(arguments.joined(separator: " "))
        case ("calendar", "show") where rest.count == 2:
            self = Self.changing(.calendarShow(id: rest[1]), "openspot calendar show", "opens Calendar", environment)
        case ("reminders", "due"):
            self = Self.listing(Array(rest.dropFirst())).map { .remindersDue(days: $0.days, hidden: $0.hidden) }
                ?? .unknown(arguments.joined(separator: " "))
        case ("reminders", "lists") where rest.count == 1: self = .remindersLists
        case ("reminders", "add"):
            self = Self.adding(Array(rest.dropFirst()), environment) { .remindersAdd(words: $0, isDry: $1) }
                .map { Self.changing($0, "openspot reminders add", "changes your reminders", environment) } ?? .unknown(arguments.joined(separator: " "))
        case ("reminders", "done") where rest.count == 2 || (rest.count == 3 && ["true", "false"].contains(rest[2])):
            self = Self.changing(.remindersDone(id: rest[1], isDone: rest.count == 2 || rest[2] == "true"), "openspot reminders done", "changes your reminders", environment)
        case ("reminders", "show") where rest.count == 2:
            self = Self.changing(.remindersShow(id: rest[1]), "openspot reminders show", "opens Reminders", environment)
        case ("translate", _):
            guard let options = Self.options(rest) else {
                self = .unknown(arguments.joined(separator: " "))
                return
            }
            self = .translate(from: options["--from"].flatMap { $0 == "auto" ? nil : $0 }, to: options["--to"])
        default: self = .unknown(arguments.joined(separator: " "))
        }
    }

    /// The call of a command that waits for the person, or its refusal in a read (K4).
    private static func waiting(_ call: CommandLineCall, _ name: String, _ environment: [String: String]) -> CommandLineCall {
        guard environment["OPENSPOT_REASON"] == nil else {
            return .refused("`\(name)` waits for the person, so it cannot run in a read. Run it from a pick or an action.")
        }
        return call
    }

    /// The call of a command that captures the screen, or its refusal in a read, so that nothing captures by surprise (S8).
    private static func capturing(_ call: CommandLineCall, _ name: String, _ environment: [String: String]) -> CommandLineCall {
        guard environment["OPENSPOT_REASON"] == nil else {
            return .refused("`\(name)` captures the screen, so it cannot run in a read. Run it from a pick or an action.")
        }
        return call
    }

    /// Reads `[--dry-run] <words>...` into the call that it makes, or returns nil with no words.
    private static func adding(_ words: [String], _ environment: [String: String], _ call: (String, Bool) -> CommandLineCall) -> CommandLineCall? {
        let isDry = words.first == "--dry-run"
        let rest = isDry ? Array(words.dropFirst()) : words
        guard !rest.isEmpty else { return nil }
        return call(rest.joined(separator: " "), isDry)
    }

    /// The call of a command that changes the person's data or opens an app, or its refusal in a read, so that nothing changes
    /// or opens by surprise. A dry run changes nothing, so it runs in a read (E9).
    private static func changing(_ call: CommandLineCall, _ name: String, _ act: String, _ environment: [String: String]) -> CommandLineCall {
        if case .calendarAdd(_, true) = call { return call }
        if case .remindersAdd(_, true) = call { return call }
        guard environment["OPENSPOT_REASON"] == nil else {
            return .refused("`\(name)` \(act), so it cannot run in a read. Run it from a pick or an action.")
        }
        return call
    }

    /// Reads the words of `openspot screen record <verb>`, or returns nil for anything else.
    private static func recording(_ words: [String], verb: String, _ environment: [String: String]) -> CommandLineCall? {
        switch verb {
        case "start": ScreenCapture(words: words, records: true).map { capturing(.screenRecordStart($0), "openspot screen record start", environment) }
        case "stop" where words.isEmpty: capturing(.screenRecordStop, "openspot screen record stop", environment)
        case "status" where words.isEmpty: .screenRecordStatus
        default: nil
        }
    }

    /// Reads `[--spot id] <key>`, and a value after the key of a set. The spot is `OPENSPOT_ID` when no `--spot` names one.
    private static func setting(_ words: [String], sets: Bool, _ environment: [String: String]) -> CommandLineCall? {
        var words = words
        var spot = environment["OPENSPOT_ID"].flatMap { $0.isEmpty ? nil : $0 }
        if words.first == spotWord {
            guard words.count > 1 else { return nil }
            spot = words[1]
            words.removeFirst(2)
        }
        guard let key = words.first, !key.isEmpty, !key.hasPrefix("-"), words.count <= (sets ? 2 : 1) else { return nil }
        guard let spot else { return .refused("`openspot setting` needs a spot. Run it from a spot, or name one with `--spot <id>`.") }
        return sets ? .settingSet(spot: spot, key: key, value: words.dropFirst().first) : .settingGet(spot: spot, key: key)
    }

    /// Reads `[--days n] [--spot id] [--frame|--json]`, each at most once, or returns nil for anything else.
    private static func stats(_ words: [String]) -> CommandLineCall? {
        var days = 1
        var spot: String?
        var format = StatsReport.Format.text
        var seen: Set<String> = []
        var index = 0
        while index < words.count {
            let word = words[index]
            guard seen.insert(["--frame", "--json"].contains(word) ? "format" : word).inserted else { return nil }
            switch word {
            case "--days":
                guard index + 1 < words.count, let number = Int(words[index + 1]), number > 0 else { return nil }
                days = min(number, SpotUsage.keptDays)
                index += 1
            case spotWord:
                guard index + 1 < words.count else { return nil }
                spot = words[index + 1]
                index += 1
            case "--frame": format = .frame
            case "--json": format = .json
            default: return nil
            }
            index += 1
        }
        return .spotStats(days: days, spot: spot, format: format)
    }

    /// Reads `--panel <key>`, `--fix <key>`, `<id> <command> [key]` or `<id> --float [key]`, or returns nil for anything else.
    private static func key(_ words: [String]) -> CommandLineCall? {
        switch words.first {
        case "--panel" where words.count == 2: return .appKeySet(name: "panel_key", key: words[1])
        case "--fix" where words.count == 2: return .appKeySet(name: "fix_key", key: words[1])
        case let spot? where !spot.hasPrefix("-") && (words.count == 2 || words.count == 3):
            let act: GlobalKey.Act = words[1] == "--float" ? .float : .command(words[1])
            guard words[1] == "--float" || !words[1].hasPrefix("-") else { return nil }
            return .keySet(spot: spot, act: act, key: words.count == 3 ? words[2] : nil)
        default: return nil
        }
    }

    /// Reads `[--days n]` and `--hide <id>`, which can repeat, or returns nil for anything else. Day 1 is today.
    private static func listing(_ words: [String]) -> (days: Int, hidden: [String])? {
        var days = 1
        var hidden: [String] = []
        var index = 0
        while index < words.count {
            guard index + 1 < words.count else { return nil }
            let value = words[index + 1]
            switch words[index] {
            case "--days":
                guard let number = Int(value), number > 0 else { return nil }
                days = number
            case "--hide": hidden.append(value)
            default: return nil
            }
            index += 2
        }
        return (days, hidden)
    }

    /// Reads `--from` and `--to`, each with a value. Returns nil for anything else.
    private static func options(_ words: [String]) -> [String: String]? {
        guard words.count.isMultiple(of: 2) else { return nil }
        var options: [String: String] = [:]
        for index in stride(from: 0, to: words.count, by: 2) {
            guard words[index] == "--from" || words[index] == "--to" else { return nil }
            options[words[index]] = words[index + 1]
        }
        return options
    }
}
