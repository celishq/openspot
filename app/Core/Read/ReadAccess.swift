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
        case .allowed: "Openspot has this access."
        case .denied: "Openspot doesn’t have this access. Click Allow… to turn it on in System Settings."
        case .unasked: "Openspot hasn’t asked for this access yet."
        case .unknown: "Openspot can’t tell whether it has this access."
        }
    }
}
