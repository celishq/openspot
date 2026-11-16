import Foundation

public enum ThemeColor: Equatable, Sendable {
    case hex(HexColor)
    case accent
    case green
    case orange
    case red

    public static let none = ThemeColor.hex(HexColor(red: 0, green: 0, blue: 0, alpha: 0))

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
}
