import Foundation

public struct CommandLink: Equatable, Sendable {
    public static let run = "command_link"
    public static let standard = URL(fileURLWithPath: "/usr/local/bin/openspot")

    public let link: URL
    public let target: URL
    public let elevated: @Sendable (String) throws -> Void

    public init(link: URL = standard, target: URL, elevated: @escaping @Sendable (String) throws -> Void) {
        self.link = link
        self.target = target
        self.elevated = elevated
    }

    public var isOn: Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)) == target.path
    }

    var row: TextBlock {
        TextBlock(fields: [
            .init(key: "row", value: Self.run),
            .init(key: "title", value: "Use openspot in Terminal"),
            .init(key: "detail", value: "The command line tool"),
            .init(key: "icon", value: "terminal"),
            .init(key: "value", value: String(isOn))
        ])
    }

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

    func set(_ isOn: Bool) throws {
        if isOn != self.isOn { _ = try toggle() }
    }

    private static func quoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    public static func == (left: CommandLink, right: CommandLink) -> Bool {
        left.link == right.link && left.target == right.target
    }
}
