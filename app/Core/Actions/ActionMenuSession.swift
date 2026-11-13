import Foundation

/// An actions menu at its item, from its open to the end of its close: what it lists, what it acts on, how far its motion
/// has come, what the hooks of its offered actions said, and where its submenu shows.
public struct ActionMenuSession {
    /// The menu opens small, grows, settles when its growth ends, and while it closes it is closed for keys and the focus.
    public enum Phase: Equatable, Sendable {
        case opening, open, settled, closing
    }

    public var menu: ActionMenu
    public let target: SpotsModel.Target
    public var phase = Phase.opening
    /// Each offered action whose hook said yes to its card, as `<owner> <action id>`.
    public var hookYes: Set<String> = []
    /// The row whose submenu the host shows beside the menu, in the panel's space.
    public var submenuRow: CGRect?

    /// Whether the menu shows at its full size.
    public var isGrown: Bool {
        phase == .open || phase == .settled
    }
}
