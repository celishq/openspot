import Foundation

public struct KeyCheck: Sendable {
    private let taken: [TakenKey]

    public init(taken: [TakenKey]) {
        self.taken = taken
    }

    public func owner(of shortcut: Shortcut) -> String? {
        taken.first { $0.shortcut == shortcut }?.owner
    }

    public func words(for shortcut: Shortcut) -> String {
        guard let owner = owner(of: shortcut) else { return "\(shortcut.label) is free." }
        return "\(shortcut.label) is \(owner)'s key."
    }
}
