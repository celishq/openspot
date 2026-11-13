import Foundation

/// An action that a spot adds to the actions menu of other cards, with the spot that runs it, the group it shows in, and
/// the origins of the cards it fits. With no origin, it fits every card. `when` names a function of a JavaScript spot that
/// says whether it shows on a card (protocol: Buttons and actions).
public struct OfferedAction: Equatable, Sendable {
    public let action: CommandAction
    /// The ID of the spot that offers it, which a press runs.
    public let owner: String
    /// The title of its group in the menu: the name of its spot, or nil for a spot of the app, whose actions have none.
    public private(set) var group: String?
    public let origins: Set<SpotDock.Origin>
    public let when: String?

    /// The words of the filter, each with its origin.
    static let words: [String: SpotDock.Origin] = ["mine": .mine, "core": .core, "builtin": .builtIn]

    public init(action: CommandAction, owner: String = "", group: String? = nil, origins: Set<SpotDock.Origin> = [], when: String? = nil) {
        self.action = action
        self.owner = owner
        self.group = group
        self.origins = origins
        self.when = when
    }

    /// The same action in the app's group, which has no header.
    func ofTheApp() -> OfferedAction {
        var offered = self
        offered.group = nil
        return offered
    }

    public func fits(_ origin: SpotDock.Origin) -> Bool {
        origins.isEmpty || origins.contains(origin)
    }
}
