import Foundation

/// The items a command prints, one JSON object per line. Each `run` value appears once.
public struct ItemLines: Equatable, Sendable {
    public private(set) var items: [SpotItem] = []
    public private(set) var errors: [String] = []

    public init(output: String) {
        let decoder = JSONDecoder()
        var runs = Set<String>()
        for line in output.split(separator: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            if let item = try? decoder.decode(SpotItem.self, from: Data(line.utf8)) {
                if runs.insert(item.run).inserted { items.append(item) }
            } else {
                errors.append(String(line))
            }
        }
    }
}
