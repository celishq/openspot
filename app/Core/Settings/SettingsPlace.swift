import Foundation

public enum SettingsPlace: Hashable, Sendable {
    case page(SettingsPage), row(String), search(String)

    public static let access = page(.access)
    public static let look = page(.look)
    public static let general = page(.general)
    public static let developer = page(.developer)
    public static let account = page(.account)

    public static func spotOf(_ id: String) -> SettingsPlace {
        .page(.spotOf(id))
    }

    public static func accessOf(_ access: MacAccess) -> SettingsPlace {
        .page(.accessOf(access))
    }

    public init?(place: String) {
        let parts = place.split(separator: "/", maxSplits: 1).map(String.init)
        let rest = parts.count > 1 ? parts[1] : nil
        switch (parts.first, rest) {
        case ("access", let id?):
            guard let access = MacAccess(rawValue: id) else { return nil }
            self = .accessOf(access)
        case ("spot", let id?): self = .spotOf(id)
        case ("row", let item?): self = .row(item)
        case ("search", let words): self = .search(words ?? "")
        case ("keys", nil), ("spot", nil): self = .general
        case ("account", nil): self = .account
        case (let word?, nil):
            guard let section = SettingsPage.Section.allCases.first(where: { $0.rawValue == word || $0.title.lowercased() == word }) else { return nil }
            self = .page(.top(section))
        default: return nil
        }
    }

    public var place: String {
        switch self {
        case .page(let page): page.place
        case .row(let item): "row/\(item)"
        case .search(let words): "search/\(words)"
        }
    }
}
