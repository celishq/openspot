import Foundation

public enum ConfigChange: Equatable, Sendable {
    case keys
    case spots([String])
    case careful
    case value(spot: String, caller: String?)
}
