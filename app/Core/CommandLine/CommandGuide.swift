import Foundation

public struct CommandGuide: Sendable {
    public let folder: URL
    let nouns: [CommandNoun]

    public init(folder: URL, nouns: [CommandNoun] = CommandNoun.all) {
        self.folder = folder
        self.nouns = nouns
    }

    public var names: [String] {
        nouns.filter { $0.guide != nil }.map(\.name).sorted()
    }

    public func text(of noun: String) throws -> String {
        guard let file = nouns.first(where: { $0.name == noun })?.guide else {
            let runs = names.map { "openspot help \($0)" }
            let list = runs.dropLast().joined(separator: ", ") + " or " + (runs.last ?? "")
            throw SpotError.fault("openspot has no guide for \(noun). Run \(list).")
        }
        return try String(contentsOf: folder.appendingPathComponent("\(file).md"), encoding: .utf8)
    }
}
