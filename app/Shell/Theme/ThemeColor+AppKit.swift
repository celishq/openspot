import AppKit
import OpenspotCore
import SwiftUI

extension ThemeColor {
    var nsColor: NSColor {
        switch self {
        case .hex(let hex) where hex.red == hex.green && hex.green == hex.blue: NSColor(white: hex.red, alpha: hex.alpha)
        case .hex(let hex): NSColor(srgbRed: hex.red, green: hex.green, blue: hex.blue, alpha: hex.alpha)
        case .accent: .controlAccentColor
        case .green: .systemGreen
        case .orange: .systemOrange
        case .red: .systemRed
        }
    }

    var color: Color {
        switch self {
        case .hex(let hex): Color(.sRGB, red: hex.red, green: hex.green, blue: hex.blue, opacity: hex.alpha)
        case .accent: .accentColor
        case .green: .green
        case .orange: .orange
        case .red: .red
        }
    }
}
