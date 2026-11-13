import Foundation

/// An action that a spot adds to the actions menu of other cards, with the origins of the cards it fits. With no origin,
/// it fits every card (protocol: Buttons and actions).
public struct OfferedAction: Equatable, Sendable {
    public let action: CommandAction
    public let origins: Set<SpotDock.Origin>

    /// The words of the filter, each with its origin.
    static let words: [String: SpotDock.Origin] = ["mine": .mine, "core": .core, "builtin": .builtIn]

    public init(action: CommandAction, origins: Set<SpotDock.Origin> = []) {
        self.action = action
        self.origins = origins
    }

    public func fits(_ origin: SpotDock.Origin) -> Bool {
        origins.isEmpty || origins.contains(origin)
    }
}
