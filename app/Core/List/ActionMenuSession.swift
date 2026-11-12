import Foundation

/// An actions menu at its item, from its open to the end of its close: what it lists, what it acts on, where it lies, and
/// how far its motion has come.
public struct ActionMenuSession {
    /// The menu opens small, grows, settles when its growth ends, and while it closes it is closed for keys and the focus.
    public enum Phase: Equatable, Sendable {
        case opening, open, settled, closing
    }

    public var menu: ActionMenu
    public let target: SpotsModel.Target
    /// Where the menu lies, once its view has placed it.
    public var frame: ActionMenuFrame?
    public var phase = Phase.opening

    /// Whether the menu shows at its full size.
    public var isGrown: Bool {
        phase == .open || phase == .settled
    }
}
