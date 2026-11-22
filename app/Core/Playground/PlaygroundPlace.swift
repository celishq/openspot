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
            spot.on?.has(.panel) == true || spot.on?.seconds != nil ? nil : "The panel reads a card with panel.open or clock.<seconds> in its on."
        }
    }
}
