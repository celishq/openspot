import Foundation

public enum SettingsPage: Hashable, Sendable {
    public enum Section: String, CaseIterable, Encodable, Identifiable, Sendable {
        case access, spots = "spot", keys, look, account, general, developer

        public var id: Self {
            self
        }

        public var title: String {
            switch self {
            case .access: "Access"
            case .spots: "Spots"
            case .keys: "Keys"
            case .look: "Look"
            case .account: "Account"
            case .general: "General"
            case .developer: "Developer"
            }
        }

        public var symbol: String {
            switch self {
            case .access: "checkmark.shield"
            case .spots: "square.grid.2x2"
            case .keys: "keyboard"
            case .look: "circle.lefthalf.filled"
            case .account: "person.crop.circle"
            case .general: "gearshape"
            case .developer: "chevron.left.forwardslash.chevron.right"
            }
        }

        public var page: SettingsPage {
            switch self {
            case .access: .access
            case .spots: .spots
            case .keys: .keys
            case .look: .look
            case .account: .account
            case .general: .general
            case .developer: .developer
            }
        }
    }

    case access, accessOf(MacAccess), spots, spotOf(String), keys, look, account, general, developer, row(String), search(String)

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
        case (let word?, nil):
            guard let section = Section.allCases.first(where: { $0.rawValue == word || $0.title.lowercased() == word }) else { return nil }
            self = section.page
        default: return nil
        }
    }

    public var place: String {
        switch self {
        case .accessOf(let access): "access/\(access.rawValue)"
        case .spotOf(let id): "spot/\(id)"
        case .row(let item): "row/\(item)"
        case .search(let words): "search/\(words)"
        default: section.title.lowercased()
        }
    }

    public var section: Section {
        switch self {
        case .access, .accessOf, .row, .search: .access
        case .spots, .spotOf: .spots
        case .keys: .keys
        case .look: .look
        case .account: .account
        case .general: .general
        case .developer: .developer
        }
    }

    public var line: String {
        switch self {
        case .access: "Spots can use features of your Mac, such as the screen or your calendars, only after you allow Openspot to access them. Each spot gets only the access it needs."
        case .spots: "The spots that come with Openspot and the ones you’ve added."
        case .keys: "Keyboard shortcuts for Openspot and your spots."
        case .look: "Choose a theme for the panel."
        case .account: "Your account signs the spots you publish, so people know that updates come from you."
        case .general: "Choose how Openspot opens and starts up."
        case .developer: "Tools for building spots and themes."
        case .accessOf, .spotOf, .row, .search: ""
        }
    }
}
