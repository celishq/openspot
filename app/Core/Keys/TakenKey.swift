import Foundation

public struct TakenKey: Equatable, Sendable {
    public let shortcut: Shortcut
    public let owner: String

    public init(shortcut: Shortcut, owner: String) {
        self.shortcut = shortcut
        self.owner = owner
    }
}
