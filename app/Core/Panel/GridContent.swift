import Foundation

public enum GridContent: Sendable {
    case cards
    case search
    case slash
    case attachment

    public var isFixed: Bool {
        self == .cards
    }
}
