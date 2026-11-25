import Foundation

public enum ReadAccess: String, Sendable {
    case allowed, denied, unasked, unknown

    public var word: String {
        switch self {
        case .allowed: "Allowed"
        case .denied: "Not allowed"
        case .unasked: "Not asked"
        case .unknown: "Unknown"
        }
    }

    public var sentence: String {
        switch self {
        case .allowed: "macOS gives it to Openspot."
        case .denied: "macOS doesn’t give it to Openspot. Allow… opens its switch in System Settings."
        case .unasked: "macOS hasn’t asked you yet."
        case .unknown: "Openspot can’t read whether macOS gives it."
        }
    }
}
