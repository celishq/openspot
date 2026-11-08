import Foundation

/// The link that puts the `openspot` command on the path of a terminal. It is on only when the link points at this app.
public struct CommandLink: Equatable, Sendable {
    /// The value of its row in a list.
    public static let run = "command_link"
    public static let standard = URL(fileURLWithPath: "/usr/local/bin/openspot")

    public let link: URL
    public let target: URL
    /// Runs a shell line with the rights of an administrator, after macOS asks the person.
    public let elevated: @Sendable (String) throws -> Void

    public init(link: URL = standard, target: URL, elevated: @escaping @Sendable (String) throws -> Void) {
        self.link = link
        self.target = target
        self.elevated = elevated
    }

    var isOn: Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)) == target.path
    }

    /// Its row in a list.
    var row: TextBlock {
        TextBlock(fields: [
            .init(key: "row", value: "Use openspot in Terminal"),
            .init(key: "detail", value: "The command line tool"),
            .init(key: "run", value: Self.run),
            .init(key: "symbol", value: "terminal"),
            .init(key: "on", value: String(isOn))
        ])
    }

    /// Adds the link when it is off, and removes it when it is on. Asks for the rights of an administrator only when the
    /// folder refuses the change. Returns the toast that names what it did.
    func toggle() throws -> String {
        let manager = FileManager.default
        if isOn {
            do { try manager.removeItem(at: link) } catch { try elevated("/bin/rm -f \(Self.quoted(link.path))") }
            return "toast=Removed openspot\n"
        }
        do {
            try manager.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
            if (try? manager.destinationOfSymbolicLink(atPath: link.path)) != nil { try manager.removeItem(at: link) }
            try manager.createSymbolicLink(atPath: link.path, withDestinationPath: target.path)
        } catch {
            let folder = Self.quoted(link.deletingLastPathComponent().path)
            try elevated("/bin/mkdir -p \(folder) && /bin/ln -sfn \(Self.quoted(target.path)) \(Self.quoted(link.path))")
        }
        return "toast=Installed openspot\n"
    }

    private static func quoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    public static func == (left: CommandLink, right: CommandLink) -> Bool {
        left.link == right.link && left.target == right.target
    }
}
