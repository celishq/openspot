import Foundation

public struct PluginHeader: Equatable, Sendable {
    public let name: String
    public let api: Int

    public init?(text: String) {
        var name: String?
        var api: Int?
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("# @") else { continue }
            let parts = trimmed.dropFirst(3).split(separator: " ", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2 else { continue }
            switch parts[0] {
            case "name": name = parts[1]
            case "api": api = Int(parts[1])
            default: continue
            }
        }
        guard let name, let api else { return nil }
        self.name = name
        self.api = api
    }
}
