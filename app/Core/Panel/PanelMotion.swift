import Foundation

/// A motion of the panel that the model starts: the sheet that grows out of its card or collapses back into it, the cards
/// that move in Edit Spots, and words that fade in at their place. The app gives each one its curve.
public enum PanelMotion: Equatable, Sendable {
    case sheet(isOpen: Bool)
    case edit
    /// The content of a sheet that slides to its place from the side that its page comes from.
    case slide
    case fade
}
