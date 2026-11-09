import Foundation

/// A motion of the panel that the model starts: the sheet that grows out of its card or collapses back into it, and the
/// cards that move in Edit Spots. The app gives each one its spring.
public enum PanelMotion: Equatable, Sendable {
    case sheet(isOpen: Bool)
    case edit
}
