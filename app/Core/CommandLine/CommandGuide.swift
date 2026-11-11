import Foundation

/// The guides of the `openspot` nouns that have one, each a Markdown file in a folder that the app ships.
public struct CommandGuide: Sendable {
    /// Each noun with a guide, and the file that holds it.
    private static let files = ["calendar": "calendar", "reminders": "calendar", "screen": "screen"]

    public static var nouns: [String] {
        files.keys.sorted()
    }

    public let folder: URL

    public init(folder: URL) {
        self.folder = folder
    }

    /// The guide of a noun. Throws a fault that lists the nouns with a guide when this one has none.
    public func text(of noun: String) throws -> String {
        guard let file = Self.files[noun] else {
            let runs = Self.nouns.map { "openspot help \($0)" }
            let list = runs.dropLast().joined(separator: ", ") + " or " + runs.last!
            throw PluginError.fault("openspot has no guide for \(noun). Run \(list).")
        }
        return try String(contentsOf: folder.appendingPathComponent("\(file).md"), encoding: .utf8)
    }
}
