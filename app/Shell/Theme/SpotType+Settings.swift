import SwiftUI

extension SpotType {
    static let settingsBadge = Font.system(size: 11, weight: .semibold)
    static let settingsChevron = Font.system(size: 11, weight: .semibold)
    static let settingsCap = Font.system(size: 11, weight: .medium)
    static let settingsLine = Font.system(size: 11)
    static let settingsTick = Font.system(size: 11, weight: .bold)
    static let settingsNumber = Font.system(size: 12, weight: .semibold)
    static let settingsTitle = Font.largeTitle.weight(.bold)
    static let settingsHeader = Font.largeTitle.weight(.bold)
    static let settingsGroup = Font.headline
    static let settingsHero = Font.title.weight(.bold)
    static let settingsBanner = Font.title.weight(.bold)
    static let settingsCompactTitle = Font.title3
    static let settingsPageLine = Font.body
    static let settingsPageTitle = Font.system(size: 15, weight: .semibold)
    static let settingsTileShare: CGFloat = 0.52
    static let settingsGlyphShare: CGFloat = 0.55

    static func settingsTile(side: CGFloat) -> Font {
        .system(size: side * settingsTileShare, weight: .medium)
    }

    static func settingsGlyph(side: CGFloat) -> Font {
        .system(size: side * settingsGlyphShare)
    }
}
