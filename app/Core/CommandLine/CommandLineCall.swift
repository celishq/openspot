import Foundation

/// What the `openspot` command was asked to do: `openspot <noun> <verb>`. No arguments start the app.
public enum CommandLineCall: Equatable, Sendable {
    case check(String?)
    case checkSheet
    case render(String)
    /// Draws the card of the output on stdin at a size, from its drawing for that size.
    case renderCard(SpotSize, String)
    case sandbox(String?)
    case catalog
    case colorPick
    /// Copies a file, or the text on stdin with no file.
    case clipboardCopy(String?)
    case clipboardPaste
    case translate(from: String?, to: String?)
    case translateLanguages
    case emoji(tone: EmojiCatalog.Tone)
    case symbols
    case windowFrame
    case windowMove(WindowMove)
    /// Runs as the helper process of a capability. A script never makes this call, so the usage does not list it.
    case helper(String)
    case help
    case unknown(String)

    public static let usage = """
    openspot check [folder]                      Reports the faults of a plugins folder.
    openspot check --sheet                       Reports the faults of a sheet on stdin.
    openspot render <file.png>                   Draws the sheet on stdin to a picture.
    openspot render --card <size> <file.png>     Draws its card at a size, such as wide, to a picture.
    openspot sandbox [file]                      Opens a window to try a sheet from text, a file or a script.
    openspot catalog                             Prints each part that a script can print.
    openspot color pick                          Prints the colour the person picks.
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

    """

    /// Returns nil when these arguments start the app, such as none or the flags that the system passes.
    public init?(arguments: [String]) {
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
        case ("render", let path?) where rest.count == 1: self = .render(path)
        case ("color", "pick") where rest.count == 1: self = .colorPick
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
