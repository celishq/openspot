import Foundation

public enum SpotReadiness: String, Sendable {
    case ready, access, review

    public var word: String {
        switch self {
        case .access: "Needs access"
        case .review: "Needs review"
        case .ready: "Ready"
        }
    }
}
