import Foundation

public struct CommandGuide: Sendable {
    private static let files = ["calendar": "calendar", "reminders": "calendar", "screen": "screen"]

    public static var nouns: [String] {
        files.keys.sorted()
    }

    public let folder: URL

    public init(folder: URL) {
        self.folder = folder
    }

    public func text(of noun: String) throws -> String {
        guard let file = Self.files[noun] else {
            let runs = Self.nouns.map { "openspot help \($0)" }
            let list = runs.dropLast().joined(separator: ", ") + " or " + runs.last!
            throw SpotError.fault("openspot has no guide for \(noun). Run \(list).")
        }
        return try String(contentsOf: folder.appendingPathComponent("\(file).md"), encoding: .utf8)
    }
}
