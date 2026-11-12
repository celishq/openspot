import Foundation

/// A place of the panel where the playground shows a spot: its sheet, or its card on the grid (protocol: Places). The
/// panel's own field searches in either.
public enum PlaygroundPlace: String, CaseIterable, Sendable {
    case sheet
    case card

    public var title: String {
        rawValue.capitalized
    }

    /// The `on` line that the spot needs before this place reads it, or nil when it has one.
    public func lack(of spot: Spot) -> String? {
        switch self {
        case .sheet:
            nil
        case .card:
            spot.read?.has(.panel) == true || spot.read?.seconds != nil ? nil : "The panel reads a card with on=panel.open or on=clock.<seconds>."
        }
    }
}
