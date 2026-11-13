import Foundation

/// An action that a spot adds to the actions menu of other cards, with the origins of the cards it fits. With no origin,
/// it fits every card. `when` names a function of a JavaScript spot that says whether it shows on a card (protocol:
/// Buttons and actions).
public struct OfferedAction: Equatable, Sendable {
    public let action: CommandAction
    public let origins: Set<SpotDock.Origin>
    public let when: String?

    /// The words of the filter, each with its origin.
    static let words: [String: SpotDock.Origin] = ["mine": .mine, "core": .core, "builtin": .builtIn]

    public init(action: CommandAction, origins: Set<SpotDock.Origin> = [], when: String? = nil) {
        self.action = action
        self.origins = origins
        self.when = when
    }

    public func fits(_ origin: SpotDock.Origin) -> Bool {
        origins.isEmpty || origins.contains(origin)
    }
}
