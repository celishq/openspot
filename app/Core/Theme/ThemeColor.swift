import Foundation

public enum ThemeColor: Equatable, Sendable {
    case hex(HexColor)
    case accent
    case green
    case orange
    case red

    public init?(text: String) {
        switch text {
        case "accent": self = .accent
        case "green": self = .green
        case "orange": self = .orange
        case "red": self = .red
        default:
            guard let hex = HexColor(text: text) else { return nil }
            self = .hex(hex)
        }
    }

    public var sample: HexColor {
        switch self {
        case .hex(let hex): hex
        case .accent: HexColor(text: "#007AFF")!
        case .green: HexColor(text: "#34C759")!
        case .orange: HexColor(text: "#FF9500")!
        case .red: HexColor(text: "#FF3B30")!
        }
    }

    public func legible(_ one: ThemeColor, or other: ThemeColor) -> ThemeColor {
        sample.contrast(with: other.sample) > sample.contrast(with: one.sample) ? other : one
    }

    public func mixed(with other: ThemeColor, by share: Double) -> ThemeColor {
        .hex(sample.mixed(with: other.sample, by: share))
    }

    public func with(alpha: Double) -> ThemeColor {
        .hex(sample.with(alpha: alpha))
    }
}
