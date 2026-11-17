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
        case .points, .colour, .variant: 0...100
        }
    }

    public var meaning: String {
        switch self {
        case .strength: "a strength from 0 to 1, such as 0.2"
        case .points: "a number of points from 0 to 100, such as 3"
        case .reach: "a number from 1 to 10, such as 3"
        case .seconds: "a time from 0 to 2 seconds, such as 0.2"
        case .scale: "a scale from 0.5 to 2, such as 1.04"
        case .colour: "a colour such as #00000099"
        case .variant: "clear or regular"
        }
    }

    public func number(_ value: ConfigDocument.Value?) -> Double? {
        let number: Double? = switch value {
        case .number(let number)?: number
        case .integer(let number)?: Double(number)
        default: nil
        }
        return number.flatMap { range.contains($0) ? $0 : nil }
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
