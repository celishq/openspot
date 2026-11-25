import Foundation

public enum PanelMotion: Equatable, Sendable {
    case sheet(isOpen: Bool)
    case edit
    case flow
    case fade
    case layout
}
