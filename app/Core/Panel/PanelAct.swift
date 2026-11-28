import Foundation

public enum PanelAct: Equatable, Sendable {
    case open
    case close
    case type(String)
    case key(ActionKey)
    case press(String)
}
