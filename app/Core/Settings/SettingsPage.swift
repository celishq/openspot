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
        case .access: "macOS gives each access, such as Screen Recording, to Openspot as a whole. Openspot passes it only to the spots whose calls need it."
        case .spots: "Each spot that comes with Openspot or that you added, and whether it can run."
        case .keys: "Every key of Openspot and of its spots."
        case .look: "The theme of the panel. Each theme keeps its exact values in its own file."
        case .account: "Your key signs each spot you publish, so people know an update is from you."
        case .general: "The keys that open Openspot, and how it starts."
        case .developer: "For those who build spots and themes."
        case .accessOf, .spotOf, .row, .search: ""
        }
    }

    public var hint: String {
        switch self {
        case .access, .row, .search: "Each spot works with all it declares, or not at all."
        case .accessOf: "Turn it off in System Settings, and every spot here stops."
        case .spots: "Click a spot to see what it uses."
        case .spotOf: "A spot gets only the uses it declares."
        case .keys: "Click a key to record a new one."
        case .look: "A theme changes only the look."
        case .account: "The account signs what you publish."
        case .general: "The settings of Openspot itself."
        case .developer: "Tools for those who build spots."
        }
    }
}
