import AppKit
import Observation
import OpenspotCore
import SwiftUI

@MainActor @Observable
final class SpotLoadedTheme {
    static let shared = SpotLoadedTheme()

    @ObservationIgnored private var theme = Theme()
    private(set) var glassTint = Color.clear

    func take(_ next: Theme) {
        guard next != theme else { return }
        theme = next
        let dark = Self.color(next.dark.glassTint)
        let light = Self.color(next.light.glassTint)
        glassTint = Color(nsColor: NSColor(name: nil) { SpotTheme.isDark($0) ? dark : light })
    }

    private static func color(_ hex: HexColor) -> NSColor {
        NSColor(srgbRed: hex.red, green: hex.green, blue: hex.blue, alpha: hex.alpha)
    }
}
