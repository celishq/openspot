import Foundation

public enum ConfigChange: Equatable, Sendable {
    case keys
    case spots([String])
    case value(spot: String, caller: String?)

    var sections: Set<Config.Section> {
        switch self {
        case .keys: [.keys]
        case .spots: [.spots]
        case .value: [.settings]
        }
    }
}
