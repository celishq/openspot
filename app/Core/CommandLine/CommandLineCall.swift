import Foundation

/// What the `openspot` command was asked to do: `openspot <noun> <verb>`. No arguments start the app.
public enum CommandLineCall: Equatable, Sendable {
    case check(String?)
    case checkSheet
    /// Draws the sheet on stdin, with the plugin's view from a Swift file when it names one.
    case render(String, view: String?)
    /// Draws the card of the output on stdin at a size, from its drawing for that size.
    case renderCard(SpotSize, String)
    case sandbox(String?)
    case catalog
    case colorPick
    case folderPick
    /// Prints the value of a spot's setting, or nothing when it has none (K6).
    case settingGet(spot: String, key: String)
    /// Keeps the value of a spot's setting, or removes it with no value (K6).
    case settingSet(spot: String, key: String, value: String?)
    /// A call that cannot run here, with the line that says why and how to fix it.
    case refused(String)
    /// Copies a file, or the text on stdin with no file.
    case clipboardCopy(String?)
    case clipboardPaste
    case translate(from: String?, to: String?)
    case translateLanguages
    case emoji(tone: EmojiCatalog.Tone)
    case symbols
    case windowFrame
    case windowMove(WindowMove)
    case screenSources
    /// Takes a picture of a source, picked by the person when the words fix none (S1).
    case screenShot(ScreenCapture)
    /// Runs as the helper process of a capability. A script never makes this call, so the usage does not list it.
    case helper(String)
    case help
    case unknown(String)

    public static let usage = """
    openspot check [folder]                      Reports the faults of a plugins folder.
    openspot check --sheet                       Reports the faults of a sheet on stdin.
    openspot render [--view file] <file.png>     Draws the sheet on stdin to a picture, with its view from a Swift file.
    openspot render --card <size> <file.png>     Draws its card at a size, such as wide, to a picture.
    openspot sandbox [file]                      Opens a window to try a sheet from text, a file or a script.
    openspot catalog                             Prints each part that a script can print.
    openspot color pick                          Prints the colour the person picks.
    openspot folder pick                         Prints the folder the person picks, or nothing after Cancel.
    openspot setting get [--spot id] <key>       Prints the value the person chose for the spot, or nothing.
    openspot setting set [--spot id] <key> [v]   Keeps a value for the spot, or removes it with no value.
    openspot clipboard copy [file]               Copies the file as Finder does, or the text on stdin.
    openspot clipboard paste                     Pastes the clipboard into the front app.
    openspot translate [--from code] [--to code] Translates the text on stdin.
    openspot translate languages                 Prints the languages it knows.
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

    """

    private static let spotWord = "--spot"

    /// Returns nil when these arguments start the app, such as none or the flags that the system passes. The environment
    /// names the spot of a setting and tells a read, in which a command that waits for the person is refused (K4).
    public init?(arguments: [String], environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let noun = arguments.first else { return nil }
        if noun == "--help" || noun == "help" {
            self = .help
            return
        }
        guard !noun.hasPrefix("-") else { return nil }
        if arguments == ["check", "--sheet"] {
            self = .checkSheet
            return
        }
        let rest = Array(arguments.dropFirst())
        switch (noun, rest.first) {
        case ("check", _) where rest.count <= 1: self = .check(rest.first)
        case ("catalog", nil): self = .catalog
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
        case ("color", "pick") where rest.count == 1: self = Self.waiting(.colorPick, "openspot color pick", environment)
        case ("folder", "pick") where rest.count == 1: self = Self.waiting(.folderPick, "openspot folder pick", environment)
        case ("setting", "get"), ("setting", "set"):
            self = Self.setting(Array(rest.dropFirst()), sets: rest.first == "set", environment) ?? .unknown(arguments.joined(separator: " "))
        case ("clipboard", "copy") where rest.count <= 2: self = .clipboardCopy(rest.dropFirst().first)
        case ("clipboard", "paste") where rest.count == 1: self = .clipboardPaste
        case ("translate", "languages") where rest.count == 1: self = .translateLanguages
        case ("helper", let name?) where rest.count == 1: self = .helper(name)
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
