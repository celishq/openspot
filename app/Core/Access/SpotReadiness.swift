import Foundation

public enum SpotReadiness: String, CaseIterable, Sendable {
    case ready, access, review

    public var word: String {
        switch self {
        case .access: "Needs access"
        case .review: "Needs review"
        case .ready: "Ready"
        }
    }

    public var line: String {
        switch self {
        case .ready: "Openspot has every access it needs."
        case .access: "It waits for an access you allow."
        case .review: "It tried something it didn’t declare."
        }
    }
}
