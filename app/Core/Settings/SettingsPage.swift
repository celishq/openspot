import Foundation

public enum SettingsPage: Hashable, Sendable {
    public enum Section: String, CaseIterable, Identifiable, Sendable {
        case access = "Access", spots = "Spots", keys = "Keys", look = "Look", account = "Account", general = "General", developer = "Developer"

        public var id: Self {
            self
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

    case access, accessOf(MacAccess), spots, spotOf(String), keys, look, account, general, developer

    public var section: Section {
        switch self {
        case .access, .accessOf: .access
        case .spots, .spotOf: .spots
        case .keys: .keys
        case .look: .look
        case .account: .account
        case .general: .general
        case .developer: .developer
        }
    }

    public var hint: String {
        switch self {
        case .access: "Each spot works with all it declares, or not at all."
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
