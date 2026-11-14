import Foundation

public enum SpotMode: String, CaseIterable, Equatable, Sendable {
    case once
    case stay
    case always
    case inline

    public var stays: Bool {
        switch self {
        case .stay, .always: true
        case .once, .inline: false
        }
    }
}
