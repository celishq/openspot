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
    static let workMark: CGFloat = 16
    static let listRowHeight: CGFloat = 40
    static let listRowGap: CGFloat = 6
    static let listIconSize: CGFloat = 24
    static let hintHeight: CGFloat = 14
    static let hintLight = 0.5
    static let hintBlock: CGFloat = rowGap + hintHeight
    static let menuRowHeight: CGFloat = 32
    static let menuRowGap: CGFloat = 2
    static let menuPadding: CGFloat = 8
    static let placeGap: CGFloat = 8
    static let sideGap: CGFloat = 20
    static let controlPadding: CGFloat = 7
    static let formLabelHeight: CGFloat = 14
    static let formLabelGap: CGFloat = 4
    static let formFieldGap: CGFloat = 12
    static let formTextHeight: CGFloat = 120
    static let halo: CGFloat = 52
    static let backdropBlur: CGFloat = 4
    static let backdropScale: CGFloat = 1
    static let backdropShade = 0.2
    static let glassShade = 0.38
    static let titleOpacity = 1.0
    static let secondaryLight = 0.7
    static let fill = 0.1
    static let selectedFill = 0.22
    static let dragFill = 0.4
    static let track = 0.2
    static let cardBlur: CGFloat = 16
    static let panelWidth: CGFloat = gridWidth + 2 * halo
    static let panelHeight: CGFloat = 2 * halo + 7 * rowHeight + 6 * rowGap + hintBlock
    static let sheetMaxHeight: CGFloat = panelHeight - 2 * halo - hintBlock

    /// How far the search field moves down to sit under the title of an open sheet.
    static let sheetFieldDrop: CGFloat = padding + glyphSize + rowGap

    static func width(columns: Int) -> CGFloat {
        CGFloat(columns) * cell + CGFloat(columns - 1) * columnGap
    }

    static func height(rows: Int) -> CGFloat {
        CGFloat(rows) * rowHeight + CGFloat(rows - 1) * rowGap
    }

    /// The space between the edge of a card and what it shows. A 1x1 widget keeps more room for its one mark.
    static func cardPadding(for size: SpotSize, isWidget: Bool) -> CGFloat {
        isWidget && size == .small ? controlPadding : padding
    }

    /// How far a sheet's rows start below its top edge.
    static let sheetRowsTop: CGFloat = sheetFieldDrop + listRowHeight + rowGap

    /// The side of a square button when a line holds this many rows.
    static func square(perLine: Int) -> CGFloat {
        (SheetPlacement.width - listRowGap * CGFloat(perLine - 1)) / CGFloat(perLine)
    }

    /// The frame of a sheet with these rows. An empty sheet keeps room for one row, and a long one stops at the panel.
    /// More than one row on a line makes square buttons.
    static func sheetRect(rows: Int, perLine: Int = 1) -> CGRect {
        let lines = CGFloat(max((rows + perLine - 1) / perLine, 1))
        let line = perLine > 1 ? square(perLine: perLine) : listRowHeight
        let height = sheetRowsTop + lines * line + (lines - 1) * listRowGap + padding
        return CGRect(x: halo, y: halo, width: gridWidth, height: min(height, sheetMaxHeight))
    }

    /// Whether a sheet with these rows shows them all with no scrolling.
    static func sheetFits(rows: Int, perLine: Int = 1) -> Bool {
        sheetRect(rows: rows, perLine: perLine).height < sheetMaxHeight
    }

    static let editorInset: CGFloat = 5

    /// The frame of a sheet that shows these parts. A tall one stops at the panel, and its parts scroll.
    static func panelRect(_ panel: SpotPanel) -> CGRect {
        let field = panel.showsRows ? SheetPlacement.fieldRoom : 0
        let height = padding + glyphSize + rowGap + field + panel.placement.height + padding
        return CGRect(x: halo, y: halo, width: gridWidth, height: min(height, sheetMaxHeight))
    }

    /// The frame of a sheet that shows this form.
    static func formRect(_ form: ItemForm) -> CGRect {
        let fields = form.fields.reduce(CGFloat(0)) { sum, field in
            sum + formLabelHeight + formLabelGap + (field.type == .multiline ? formTextHeight : listRowHeight)
        }
        let gaps = CGFloat(max(form.fields.count - 1, 0)) * formFieldGap
        let height = padding + glyphSize + rowGap + fields + gaps + padding
        return CGRect(x: halo, y: halo, width: gridWidth, height: min(height, sheetMaxHeight))
    }

    static func menuHeight(rows: Int) -> CGFloat {
        CGFloat(rows) * menuRowHeight + CGFloat(max(rows - 1, 0)) * menuRowGap + 2 * menuPadding
    }

    /// The height of the blur around the search field and these card rows. It stops at the height of the panel.
    static func backdropHeight(rows: Int) -> CGFloat {
        let cards = rows > 0 ? rowGap + height(rows: rows) : 0
        return min(2 * halo + rowHeight + cards + hintBlock, panelHeight)
    }

    static func corner(for size: SpotSize) -> CGFloat {
        size.rows == 1 && size.columns < columns ? rowHeight / 2 : radius
    }
}
