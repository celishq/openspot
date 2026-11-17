import Foundation

public enum ThemeKind: Equatable, Sendable {
    case colour
    case strength
    case points
    case reach
    case seconds
    case scale
    case variant

    private static let hundredths = 100.0

    public var range: ClosedRange<Double> {
        switch self {
        case .strength: 0...1
        case .reach: 1...10
        case .seconds: 0...2
        case .scale: 0.5...2
        case .points, .colour, .variant: 0...200
        }
    }

    public var step: Double {
        switch self {
        case .points: 1
        case .reach: 0.5
        case .strength, .seconds, .scale, .colour, .variant: 0.01
        }
    }

    public func value(_ number: Double) -> ConfigDocument.Value {
        let near = (min(max(number, range.lowerBound), range.upperBound) * Self.hundredths).rounded() / Self.hundredths
        return self == .points && near == near.rounded() ? .integer(Int(near)) : .number(near)
    }
}
