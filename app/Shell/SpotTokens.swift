import CoreGraphics
import OpenspotCore
import SwiftUI

enum SpotTokens {
    static let radius: CGFloat = 26
    static let columnGap: CGFloat = 12
    static let rowGap: CGFloat = 14
    static let padding: CGFloat = 13
    static let gridWidth: CGFloat = 292
    static let columns = 4
    static let cell: CGFloat = (gridWidth - columnGap * CGFloat(columns - 1)) / CGFloat(columns)
    static let rowHeight: CGFloat = 62
    static let glyphSize: CGFloat = 36
    static let listRowHeight: CGFloat = 40
    static let listRowGap: CGFloat = 6
    static let listIconSize: CGFloat = 24
    static let halo: CGFloat = 52
    static let backdropBlur: CGFloat = 4
    static let backdropScale: CGFloat = 0.5
    static let backdropShade = 0.2
    static let glassShade = 0.38
    static let titleOpacity = 0.85
    static let secondaryLight = 0.55
    static let cardBlur: CGFloat = 16
    static let panelWidth: CGFloat = gridWidth + 2 * halo
    static let panelHeight: CGFloat = 2 * halo + 7 * rowHeight + 6 * rowGap
    static let sheetRect = CGRect(x: halo, y: halo, width: gridWidth, height: panelHeight - 2 * halo)

    /// How far the search field moves down to sit under the title of an open sheet.
    static let sheetFieldDrop: CGFloat = padding + glyphSize + rowGap

    static func width(columns: Int) -> CGFloat {
        CGFloat(columns) * cell + CGFloat(columns - 1) * columnGap
    }

    static func height(rows: Int) -> CGFloat {
        CGFloat(rows) * rowHeight + CGFloat(rows - 1) * rowGap
    }

    static func corner(for size: SpotSize) -> CGFloat {
        size.rows == 1 && size.columns < columns ? rowHeight / 2 : radius
    }
}
