import Foundation

public struct CallRule: Equatable, Sendable {
    public enum Read: Equatable, Sendable {
        case free
        case changes(String)
        case waits
        case captures
    }

    public struct Flags: OptionSet, Equatable, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let startsScripts = Flags(rawValue: 1)
        public static let reachesKey = Flags(rawValue: 2)
        public static let readsInput = Flags(rawValue: 4)
        public static let ownProcess = Flags(rawValue: 8)
    }

    public var use: SpotUse?
    public var used: String
    public var read: Read
    public var flags: Flags
    public var onlyPerson: String?

    public init(use: SpotUse? = nil, used: String = "", read: Read = .free, flags: Flags = [], onlyPerson: String? = nil) {
        self.use = use
        self.used = used
        self.read = read
        self.flags = flags
        self.onlyPerson = onlyPerson
    }

    func refusal(of name: String) -> String? {
        let act = switch read {
        case .free: ""
        case .changes(let act): act
        case .waits: "waits for the person"
        case .captures: "captures the screen"
        }
        return act.isEmpty ? nil : "`openspot \(name)` \(act), so it cannot run in a read. Run it from a pick or an action."
    }

    var isBatched: Bool {
        flags.isDisjoint(with: [.startsScripts, .readsInput, .ownProcess]) && read != .waits && read != .captures
    }
}
