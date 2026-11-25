import SwiftUI

extension SpotType {
    static let settingsBadge = Font.system(size: 11, weight: .semibold)
    static let settingsChevron = Font.system(size: 11, weight: .semibold)
    static let settingsCap = Font.system(size: 11, weight: .medium)
    static let settingsLine = Font.system(size: 11)
    static let settingsUse = Font.system(size: 12, design: .monospaced)
    static let settingsTick = Font.system(size: 11, weight: .bold)
    static let settingsNumber = Font.system(size: 12, weight: .semibold)
    static let settingsTitle = Font.title2.weight(.semibold)
    static let settingsHeader = Font.title3.weight(.semibold)
    static let settingsTileShare: CGFloat = 0.52
    static let settingsSymbolShare: CGFloat = 0.5
    static let settingsGlyphShare: CGFloat = 0.55

    static func settingsTile(side: CGFloat) -> Font {
        .system(size: side * settingsTileShare, weight: .medium)
    }

    static func settingsSymbol(side: CGFloat) -> Font {
        .system(size: side * settingsSymbolShare)
    }

    static func settingsGlyph(side: CGFloat) -> Font {
        .system(size: side * settingsGlyphShare)
    }
}
