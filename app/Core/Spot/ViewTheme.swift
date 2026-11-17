import Foundation

public struct ViewTheme: Equatable, Sendable {
    public let numbers: [String: CGFloat]

    public init(sizes: SpotSizes, motion: Theme.Motion, corner: CGFloat) {
        numbers = [
            "padding": sizes.padding, "columnGap": sizes.columnGap, "rowGap": sizes.rowGap, "listRow": sizes.listRow,
            "listRowGap": sizes.listRowGap, "glyph": sizes.glyph, "cell": sizes.cell, "gridWidth": sizes.gridWidth,
            "card": sizes.cardRadius, "media": sizes.mediaRadius, "inner": max(corner - sizes.padding, 0),
            "press": motion.press, "pressBounce": motion.pressBounce
        ]
    }
}
