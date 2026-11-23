import Foundation

public enum KeyWidth {
    public static let widest: Double = 2
    private static let wide: Double = 1.5
    private static let command: Double = 1.25
    private static let wideLabels: Set<String> = ["⏎", "⌫", "Tab"]

    public static func of(_ modifier: Shortcut.Modifiers) -> Double {
        switch modifier {
        case .shift: wide
        case .command: command
        default: 1
        }
    }

    public static func of(label: String) -> Double {
        if label == "Space" { return widest }
        return wideLabels.contains(label) ? wide : 1
    }
}
