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

        Before you change a file here, run `openspot guide build-and-check-a-spot` and follow it. `openspot guide --topics`
        lists the other pages of the guide. Read each one that your change needs.

        """
    }
}
