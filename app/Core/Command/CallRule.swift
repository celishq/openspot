import Foundation

public struct CallRule: Equatable, Sendable {
    public enum InShow: Equatable, Sendable {
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
        public static let events = Flags(rawValue: 16)
        public static let needsApp = Flags(rawValue: 32)
        public static let pure = Flags(rawValue: 64)
    }

    public var use: SpotUse?
    public var used: String
    public var inShow: InShow
    public var flags: Flags
    public var onlyPerson: String?

    public init(use: SpotUse? = nil, used: String = "", inShow: InShow = .free, flags: Flags = [], onlyPerson: String? = nil) {
        self.use = use
        self.used = used
        self.inShow = inShow
        self.flags = flags
        self.onlyPerson = onlyPerson
    }

    var act: (effect: String, words: String?) {
        switch inShow {
        case .free: ("read", nil)
        case .changes(let act): ("changes", act)
        case .waits: ("waits", "waits for the person")
        case .captures: ("captures", "captures the screen")
        }
    }

    func refusal(of name: String) -> String? {
        act.words.map { "`openspot \(name)` \($0), so it cannot run in a read. Run it from a pick or an action." }
    }

    var isBatched: Bool {
        flags.isDisjoint(with: [.startsScripts, .readsInput, .ownProcess]) && inShow != .waits && inShow != .captures
    }
}
