import Foundation

public struct SearchQuery: Equatable, Sendable {
    public let text: String

    public init(text: String) {
        self.text = text.trimmingCharacters(in: .whitespaces)
    }

    public func matching(_ rows: [Row]) -> [Row] {
        guard !text.isEmpty else { return rows }
        return rows.filter { row in
            row.title.localizedCaseInsensitiveContains(text)
                || (row.subtitle?.localizedCaseInsensitiveContains(text) ?? false)
        }
    }
}
