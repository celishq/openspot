import Foundation

public enum ThemeKind: Equatable, Sendable {
    case colour
    case strength
    case seconds
    case scale
    case factor
    case points(ClosedRange<Double> = 0...100, example: Int = 3)
    case words([String])

    public var range: ClosedRange<Double>? {
        switch self {
        case .strength: 0...1
        case .seconds: 0...2
        case .scale: 0.5...2
        case .factor: 0.25...4
        case .points(let range, _): range
        case .colour, .words: nil
        }
    }

    public var meaning: String {
        switch self {
        case .strength: "a strength from 0 to 1, such as 0.2"
        case .seconds: "a time from 0 to 2 seconds, such as 0.2"
        case .scale: "a scale from 0.5 to 2, such as 1.04"
        case .factor: "a factor from 0.25 to 4, such as 1.5"
        case .colour: "a colour such as #00000099"
        case .points(let range, let example): "a number of points from \(Int(range.lowerBound)) to \(Int(range.upperBound)), such as \(example)"
        case .words(let words): words.joined(separator: " or ")
        }
    }

    public func accepts(_ value: ConfigDocument.Value?) -> Bool {
        switch (self, value) {
        case (.colour, .string(let text)?): ThemeColor(text: text) != nil
        case (.words(let words), .string(let text)?): words.contains(text)
        case (.colour, _), (.words, _): false
        default: number(value) != nil
        }
    }

    public func number(_ value: ConfigDocument.Value?) -> Double? {
        let number: Double? = switch value {
        case .number(let number)?: number
        case .integer(let number)?: Double(number)
        default: nil
        }
        return number.flatMap { range?.contains($0) == true ? $0 : nil }
    }
}
