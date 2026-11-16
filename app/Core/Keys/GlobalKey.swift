import Foundation

public struct GlobalKey: Hashable, Sendable {
    public enum Act: Hashable, Sendable {
        case open
        case float
        case command(String)

        private static let commandPrefix = "key."

        public init?(setting: String) {
            switch setting {
            case "open": self = .open
            case "float": self = .float
            case let key where key.hasPrefix(Self.commandPrefix): self = .command(String(key.dropFirst(Self.commandPrefix.count)))
            default: return nil
            }
        }

        public var setting: String {
            switch self {
            case .open: "open"
            case .float: "float"
            case .command(let id): Self.commandPrefix + id
            }
        }
    }

    public let spot: String
    public let act: Act
    public let trigger: Trigger

    public init(spot: String, act: Act, trigger: Trigger) {
        self.spot = spot
        self.act = act
        self.trigger = trigger
    }

    public init(spot: String, command: String, shortcut: Shortcut) {
        self.init(spot: spot, act: .command(command), trigger: .key(shortcut))
    }

    var table: ConfigDocument.Table {
        let command: String? = if case .command(let id) = act { id } else { nil }
        return ConfigDocument.Table("keys", [("spot", .string(spot)), ("command", command.map { .string($0) }), ("open", act == .open ? .boolean(true) : nil), ("key", .string(trigger.text))])
    }
}
