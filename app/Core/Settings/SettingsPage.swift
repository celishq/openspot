import Foundation

public enum SettingsPage: Hashable, Sendable {
    public enum Section: String, CaseIterable, Encodable, Identifiable, Sendable {
        case general, look, access, developer

        public var id: Self {
            self
        }

        public var title: String {
            switch self {
            case .access: "Privacy"
            case .look: "Look"
            case .general: "General"
            case .developer: "Developer"
            }
        }

        public var symbol: String {
            switch self {
            case .access: "checkmark.shield"
            case .look: "circle.lefthalf.filled"
            case .general: "gearshape"
            case .developer: "chevron.left.forwardslash.chevron.right"
            }
        }

        public var line: String {
            switch self {
            case .access: "Spots can use features of your Mac, such as the screen or your calendars, only after you allow Openspot to access them. Each spot gets only the access it needs."
            case .look: "Choose a theme for the panel."
            case .general: "What needs you, and how Openspot opens and starts up."
            case .developer: "Tools for building spots and themes."
            }
        }
    }

    case top(Section), account, accessOf(MacAccess), spotOf(String)

    public static let access = top(.access)
    public static let look = top(.look)
    public static let general = top(.general)
    public static let developer = top(.developer)

    public var place: String {
        switch self {
        case .accessOf(let access): "access/\(access.rawValue)"
        case .spotOf(let id): "spot/\(id)"
        case .account: "account"
        case .top(let section): section.rawValue
        }
    }
}
