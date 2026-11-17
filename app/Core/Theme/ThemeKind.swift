import Foundation

public enum ThemeKind: Equatable, Sendable {
    case colour
    case strength
    case points
    case seconds
    case scale
    case factor
    case variant
    case backdropLook
    case backdropReach
    case haloSize
    case haloPadding

    public var range: ClosedRange<Double> {
        switch self {
        case .strength: 0...1
        case .seconds: 0...2
        case .scale: 0.5...2
        case .factor: 0.25...4
        case .haloSize: Double(SpotTokens.backdropLeastFade)...Double(SpotTokens.halo)
        case .haloPadding: 0...Double(SpotTokens.halo - SpotTokens.backdropLeastFade)
        case .points, .colour, .variant, .backdropLook, .backdropReach: 0...100
        }
    }

    public var meaning: String {
        switch self {
        case .strength: "a strength from 0 to 1, such as 0.2"
        case .points: "a number of points from 0 to 100, such as 3"
        case .seconds: "a time from 0 to 2 seconds, such as 0.2"
        case .scale: "a scale from 0.5 to 2, such as 1.04"
        case .factor: "a factor from 0.25 to 4, such as 1.5"
        case .colour: "a colour such as #00000099"
        case .variant: "clear or regular"
        case .backdropLook: "blur or tint"
        case .backdropReach: "tiles or screen"
        case .haloSize: "a number of points from \(Int(range.lowerBound)) to \(Int(range.upperBound)), such as 60"
        case .haloPadding: "a number of points from \(Int(range.lowerBound)) to \(Int(range.upperBound)), such as 10"
        }
    }

    public var words: [String]? {
        switch self {
        case .variant: ["clear", "regular"]
        case .backdropLook: ["blur", "tint"]
        case .backdropReach: ["tiles", "screen"]
        default: nil
        }
    }

    public func accepts(_ value: ConfigDocument.Value?) -> Bool {
        switch (self, value) {
        case (.colour, .string(let text)?): ThemeColor(text: text) != nil
        case (.colour, _): false
        case (_, .string(let text)?): words?.contains(text) == true
        default: words == nil && number(value) != nil
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
