import Foundation

public struct ActionMenuSession {
    public enum Phase: Equatable, Sendable {
        case opening, open, settled, closing
    }

    public var menu: ActionMenu
    public let target: SpotsModel.Target
    public var phase = Phase.opening
    public var answers = HookAnswers()
    public var submenuRow: CGRect?

    public var isGrown: Bool {
        phase == .open || phase == .settled
    }
}
