import Foundation

public struct KeyCheck: Sendable {
    private let taken: [TakenKey]

    public init(taken: [TakenKey]) {
        self.taken = taken
    }

    public func use(of shortcut: Shortcut) -> String? {
        taken.first { $0.shortcut == shortcut }?.use
    }

    public func words(for shortcut: Shortcut) -> String {
        guard let use = use(of: shortcut) else { return "\(shortcut.label) is free." }
        return "\(shortcut.label) \(use)."
    }
}
