import Foundation

struct MissedSearch: Equatable {
    static let shortest = 3

    private(set) var text: String?

    mutating func landed(_ query: String, found: Bool) {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).lowercased()
        guard text.map({ !$0.hasPrefix(search) }) ?? true else { return }
        text = !found && search.count >= Self.shortest && !search.hasPrefix("/") ? search : nil
    }

    mutating func drop() {
        text = nil
    }

    mutating func take() -> String? {
        defer { text = nil }
        return text
    }
}
