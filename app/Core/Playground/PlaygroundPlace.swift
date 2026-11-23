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
            spot.triggers.has(.panel) || spot.triggers.seconds != nil ? nil : "The panel reads a card with \"panel.open\" or every in its [on]."
        }
    }
}
