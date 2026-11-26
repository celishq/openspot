import Foundation

public enum SpotReadiness: String, Sendable {
    case ready, access, review, off

    public var word: String {
        switch self {
        case .access: "Needs access"
        case .review: "Needs review"
        case .off: "Off"
        case .ready: "Ready"
        }
    }
}
