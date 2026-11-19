import Foundation

public enum SpotMode: String, CaseIterable, Equatable, Sendable {
    case once
    case stay
    case inline

    public var stays: Bool {
        switch self {
        case .stay: true
        case .once, .inline: false
        }
    }
}
