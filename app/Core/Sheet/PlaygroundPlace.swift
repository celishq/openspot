import Foundation

public enum PlaygroundPlace: String, CaseIterable, Sendable {
    case sheet
    case card

    public var title: String {
        rawValue.capitalized
    }

    public func lack(of spot: Spot) -> String? {
        switch self {
        case .sheet:
            nil
        case .card:
            spot.read?.has(.panel) == true || spot.read?.seconds != nil ? nil : "The panel reads a card with on=panel.open or on=clock.<seconds>."
        }
    }
}
