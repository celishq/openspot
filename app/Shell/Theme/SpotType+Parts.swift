import SwiftUI

extension SpotType {
    static let leastValueScale: CGFloat = 0.6
    static let leastWordsScale: CGFloat = 0.7
    static let leastViewScale: CGFloat = 0.5
    static let leastNumberScale: CGFloat = 0.5
    static let leastBigNumberScale: CGFloat = 0.2
    static let slotNumberSize: CGFloat = 28
    static let slotNumberShare: CGFloat = 0.8
    static let roundSymbolShare: CGFloat = 0.32
    static let roundSymbolLeast: CGFloat = 10
    static let itemGlyphShare = 0.8
    static let itemSymbolShare: CGFloat = 0.7

    static let publisherHandle = Font.system(size: 24, weight: .bold)
    static let publisherTitle = Font.system(size: 9.5, weight: .bold)
    static let publisherTracking: CGFloat = 1.9
    static let publisherSince = Font.system(size: 10.5, weight: .medium)
    static let publisherKey = Font.system(size: 10.5, weight: .medium, design: .monospaced)
    static let publisherCopy = Font.system(size: 9, weight: .semibold)

    static func slotNumber(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func roundSymbol(side: CGFloat) -> Font {
        .system(size: max(side * roundSymbolShare, roundSymbolLeast), weight: .semibold)
    }

    static func itemGlyph(side: CGFloat) -> Font {
        .system(size: side * itemGlyphShare)
    }

    static func itemSymbol(side: CGFloat) -> Font {
        .system(size: side * itemSymbolShare, weight: .medium)
    }
}
