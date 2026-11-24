import Foundation

public struct AgentNote: Equatable, Sendable {
    static let mark = "<!-- Openspot keeps this file up to date. Write your own rules in another file. -->"
    static let name = "AGENTS.md"
    static let pointerName = "CLAUDE.md"

    public let command: String

    public init(command: String) {
        self.command = command
    }

    public func write(in folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let note = folder.appendingPathComponent(Self.name)
        let old = try? String(contentsOf: note, encoding: .utf8)
        if old == nil || (old?.hasPrefix(Self.mark) == true && old != text) {
            try text.write(to: note, atomically: true, encoding: .utf8)
        }
        let pointer = folder.appendingPathComponent(Self.pointerName)
        if !FileManager.default.fileExists(atPath: pointer.path) {
            try "@\(Self.name)\n".write(to: pointer, atomically: true, encoding: .utf8)
        }
    }

    var text: String {
        """
        \(Self.mark)
        # Openspot spots

        This folder holds the spots of Openspot, a launcher for the Mac. Each spot is one folder of files one level down, such as
        `weather.spot`, and its `spot.toml` describes each script in it. The ID of a spot is its path with no extension, such as
        `weather` or `home/coffee`.

        In this file, `openspot` stands for `"\(command)"`. Type that full path in quotes, since it can hold a space, when `openspot` is not on the PATH.

        Before you change a file here, run `openspot guide` and read all of it. It is the contract that each spot follows.

        1. Make a spot: `openspot spot new "<name>" --from button`. In place of `button`, use `list`, `number` or `form`.
           It prints the file to change.
        2. Try a call as the app makes it: `openspot spot run <id> [call] [value]...`. With no call, it reads a spot whose
           `spot.toml` lists an event in `on`, and runs a spot that lists none.
        3. Look at the card: `openspot render spot <id> --card wide card.png`, then open `card.png`.
        4. Check: `openspot check spots --json` must print `[]`. Fix each fault that it lists, then check again.
        5. At the end of your answer to the person, run `openspot spot open <id> --select`. It opens the panel with the spot selected.
           Then tell the person what the spot runs on their Mac.

        When the person says that a spot does not work, run `openspot spot log <id>` first. It prints the last calls that the
        app made to the spot, each with its stdin, its stdout, its stderr and its exit code.

        """
    }
}
