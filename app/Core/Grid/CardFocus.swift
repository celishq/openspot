/// How a card shows while an actions menu is open: its own card comes forward and the rest fade.
public enum CardFocus: Equatable, Sendable {
    case none, focused, faded
}
