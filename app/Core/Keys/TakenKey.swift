import Foundation

public struct TakenKey: Equatable, Sendable {
    public let shortcut: Shortcut
    public let use: String

    public init(shortcut: Shortcut, use: String) {
        self.shortcut = shortcut
        self.use = use
    }
}
