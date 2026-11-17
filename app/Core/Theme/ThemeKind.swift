import Foundation

public enum ThemeKind: Equatable, Sendable {
    case colour
    case strength
    case points
    case reach
    case seconds
    case scale
    case variant
    case backdropLook
    case backdropReach
    case haloSize
    case haloPadding

    public var range: ClosedRange<Double> {
        switch self {
        case .strength: 0...1
        case .reach: 1...10
        case .seconds: 0...2
        case .scale: 0.5...2
        case .haloSize: Double(SpotTokens.backdropLeastFade)...Double(SpotTokens.halo)
        case .haloPadding: 0...Double(SpotTokens.halo - SpotTokens.backdropLeastFade)
        case .points, .colour, .variant, .backdropLook, .backdropReach: 0...100
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
        case .backdropLook: "blur or tint"
        case .backdropReach: "tiles or screen"
        case .haloSize: "a number of points from \(Int(range.lowerBound)) to \(Int(range.upperBound)), such as 60"
        case .haloPadding: "a number of points from \(Int(range.lowerBound)) to \(Int(range.upperBound)), such as 10"
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
}
