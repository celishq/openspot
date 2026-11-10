import Foundation

/// The sizes and gaps of the panel, and the places they give the field, the grid, the cards and the sheets.
public enum SpotTokens {
    public static let radius: CGFloat = 26
    public static let columnGap: CGFloat = 11
    public static let rowGap: CGFloat = 12
    public static let padding: CGFloat = 13
    public static let gridWidth: CGFloat = 289
    public static let columns = 4
    public static let cell: CGFloat = (gridWidth - columnGap * CGFloat(columns - 1)) / CGFloat(columns)
    public static let rowHeight: CGFloat = 64
    public static let glyphSize: CGFloat = 36
    public static let workMark: CGFloat = 16
    public static let keycap: CGFloat = 20
    public static let keycapRadius: CGFloat = 6
    /// The side of the square that takes a drag of a card's resize handle, and the width of its line on the rim.
    public static let resizeHandle: CGFloat = 28
    public static let resizeHandleLine: CGFloat = 5
    /// The widest the dock of Edit Spots grows, the height of a spot in it, a card with the room for a name under it, and
    /// the dock's gap to the edges of the screen.
    public static let dockWidth: CGFloat = 1220
    public static let dockNameGap: CGFloat = 4
    public static let dockNameHeight: CGFloat = 14
    public static let dockTileHeight: CGFloat = rowHeight + dockNameGap + dockNameHeight
    public static let dockMargin: CGFloat = 20
    /// The most rows of spots that the dock shows before it scrolls.
    public static let dockRows = 3
    /// Where the dock's first row of spots starts, under its title and its search.
    public static let dockRowsTop: CGFloat = padding + menuRowHeight + rowGap
    /// The step, in degrees, in which the pointer over a resize handle turns, and how near the centre of the card's corner
    /// the pointer keeps the angle it has.
    public static let handleAngleStep = 5
    public static let handleStill: CGFloat = 4
    /// How far from each edge the rim of a round corner passes through its diagonal, as a part of the radius.
    public static let rimPoint: CGFloat = 1 - 0.5.squareRoot()
    public static let listRowHeight: CGFloat = 40
    public static let listRowGap: CGFloat = 6
    public static let listIconSize: CGFloat = 24
    public static let hintHeight: CGFloat = 14
    public static let hintPillInset: CGFloat = 4
    public static let hintKeyHeight: CGFloat = 16
    /// The gap from a key to the edge of the hint, the same on each side, so that the two curves share one centre.
    public static let hintKeyInset: CGFloat = hintHeight / 2 + hintPillInset - hintKeyHeight / 2
    public static let hintKeyPadding: CGFloat = 5
    public static let hintKeyGap: CGFloat = 4
    public static let hintGroupGap: CGFloat = 12
    public static let hintEndPadding: CGFloat = 10
    public static let hintPillHeight: CGFloat = hintHeight + 2 * hintPillInset
    /// The room under the cards for the hint: one gap, then the hint's pill.
    public static let hintBlock: CGFloat = rowGap + hintPillHeight
    public static let menuRowHeight: CGFloat = 32
    public static let menuRowGap: CGFloat = 2
    public static let menuPadding: CGFloat = 8
    public static let placeGap: CGFloat = 8
    public static let sideGap: CGFloat = 20
    public static let controlPadding: CGFloat = 7
    public static let formLabelHeight: CGFloat = 14
    public static let formLabelGap: CGFloat = 4
    public static let formFieldGap: CGFloat = 12
    public static let formTextHeight: CGFloat = 120
    public static let halo: CGFloat = 90
    public static let panelWidth: CGFloat = gridWidth + 2 * halo
    public static let panelHeight: CGFloat = 2 * halo + 7 * rowHeight + 6 * rowGap + hintBlock
    public static let sheetMaxHeight: CGFloat = panelHeight - 2 * halo - hintBlock

    /// How far the search field moves down to sit under the title of an open sheet.
    public static let sheetFieldDrop: CGFloat = padding + glyphSize + rowGap

    public static func width(columns: Int) -> CGFloat {
        CGFloat(columns) * cell + CGFloat(columns - 1) * columnGap
    }

    public static func height(rows: Int) -> CGFloat {
        CGFloat(rows) * rowHeight + CGFloat(rows - 1) * rowGap
    }

    /// The height of the dock when it shows this many rows of spots.
    public static func dockHeight(rows: Int) -> CGFloat {
        dockRowsTop + CGFloat(rows) * dockTileHeight + CGFloat(rows - 1) * rowGap + padding
    }

    /// How many columns of spots a dock this wide holds, two at least.
    public static func dockColumns(width: CGFloat) -> Int {
        max(Int((width - 2 * padding + columnGap) / (cell + columnGap)), 2)
    }

    /// The angle in degrees, from level to upright in steps of `handleAngleStep`, of the arrow at this point of a card's
    /// corner handle: the line from the corner's centre to the point, which past the handle eases towards the diagonal.
    /// Nil within `handleStill` of the centre.
    public static func handleAngle(of size: SpotSize, at point: CGPoint) -> Int? {
        let centre = resizeHandle - corner(for: size)
        let dx = point.x - centre, dy = point.y - centre
        let distance = hypot(dx, dy)
        guard distance >= handleStill else { return nil }
        let line = (atan2(dy, dx) * 180 / .pi + 360).truncatingRemainder(dividingBy: 180)
        let held = line <= 90 ? line : line < 135 ? 90 : 0
        let reach = (resizeHandle - centre) * 2.squareRoot()
        let eased = 45 + (held - 45) * min(reach / distance, 1)
        let step = CGFloat(handleAngleStep)
        return Int((eased / step).rounded() * step)
    }

    /// The space between the edge of a card and what it shows. A 1x1 widget keeps more room for its one mark.
    public static func cardPadding(for size: SpotSize, isWidget: Bool) -> CGFloat {
        isWidget && size == .small ? controlPadding : padding
    }

    /// The side of a picture in a slot: a row icon in a room one list row high, else most of its room, and never more than its room.
    public static func pictureSide(in room: CGSize) -> CGFloat {
        let fit = min(room.width, room.height)
        return min(fit, room.height <= listRowHeight ? listIconSize : fit * 0.6)
    }

    /// The height of a list row that takes this many list row heights, with the gaps between them.
    public static func listRowHeight(span: Int) -> CGFloat {
        CGFloat(span) * listRowHeight + CGFloat(span - 1) * listRowGap
    }

    /// How far a sheet's rows start below its top edge.
    public static let sheetRowsTop: CGFloat = sheetFieldDrop + listRowHeight + rowGap

    /// The side of a square button when a line holds this many rows.
    public static func square(perLine: Int) -> CGFloat {
        (SheetPlacement.width - listRowGap * CGFloat(perLine - 1)) / CGFloat(perLine)
    }

    /// The frame of a sheet with these rows. An empty sheet keeps room for one row, and a long one stops at the panel.
    /// More than one row on a line makes square buttons.
    public static func sheetRect(rows: Int, perLine: Int = 1) -> CGRect {
        let lines = CGFloat(max((rows + perLine - 1) / perLine, 1))
        let line = perLine > 1 ? square(perLine: perLine) : listRowHeight
        let height = sheetRowsTop + lines * line + (lines - 1) * listRowGap + padding
        return CGRect(x: halo, y: halo, width: gridWidth, height: min(height, sheetMaxHeight))
    }

    /// How many rows the tallest sheet shows before it scrolls, with one line to spare for a drawing whose cells are smaller
    /// than its places on a line make them.
    public static func firstScreen(perLine: Int) -> Int {
        let line = perLine > 1 ? square(perLine: perLine) : listRowHeight
        let lines = ((sheetMaxHeight - sheetRowsTop - padding) / (line + listRowGap)).rounded(.up)
        return (Int(lines) + 1) * max(perLine, 1)
    }

    /// The size of a float's sheet: its header, then its parts or its rows, with no search field. A tall one stops at the
    /// height of the panel's sheet, and its rows scroll.
    public static func floatSize(rows: Int, perLine: Int = 1, parts: SheetParts? = nil) -> CGSize {
        let content: CGFloat
        if let parts {
            content = parts.placement.height
        } else {
            let lines = CGFloat(max((rows + perLine - 1) / perLine, 1))
            content = lines * (perLine > 1 ? square(perLine: perLine) : listRowHeight) + (lines - 1) * listRowGap
        }
        return CGSize(width: gridWidth, height: min(padding + glyphSize + rowGap + content + padding, sheetMaxHeight))
    }

    /// Whether a sheet with these rows shows them all with no scrolling.
    public static func sheetFits(rows: Int, perLine: Int = 1) -> Bool {
        sheetRect(rows: rows, perLine: perLine).height < sheetMaxHeight
    }

    public static let editorInset: CGFloat = 5

    /// The frame of a sheet that shows these parts. A tall one stops at the panel, and its parts scroll.
    public static func panelRect(_ panel: SheetParts) -> CGRect {
        let field = panel.showsRows ? SheetPlacement.fieldRoom : 0
        let height = padding + glyphSize + rowGap + field + panel.placement.height + padding
        return CGRect(x: halo, y: halo, width: gridWidth, height: min(height, sheetMaxHeight))
    }

    /// The frame of a sheet that shows this form. A form of one choice shows the search field over a row for each option.
    public static func formRect(_ form: ItemForm) -> CGRect {
        if let choice = form.soleChoice {
            let rows = CGFloat(max(choice.options.count, 1))
            let height = padding + glyphSize + rowGap + listRowHeight + rowGap + rows * listRowHeight + (rows - 1) * listRowGap + padding
            return CGRect(x: halo, y: halo, width: gridWidth, height: min(height, sheetMaxHeight))
        }
        let fields = form.fields.reduce(CGFloat(0)) { sum, field in
            sum + formLabelHeight + formLabelGap + (field.type == .multiline ? formTextHeight : listRowHeight)
        }
        let gaps = CGFloat(max(form.fields.count - 1, 0)) * formFieldGap
        let height = padding + glyphSize + rowGap + fields + gaps + padding
        return CGRect(x: halo, y: halo, width: gridWidth, height: min(height, sheetMaxHeight))
    }

    public static func menuHeight(rows: Int) -> CGFloat {
        CGFloat(rows) * menuRowHeight + CGFloat(max(rows - 1, 0)) * menuRowGap + 2 * menuPadding
    }

    /// The height of the blur around the search field and these card rows. It stops at the height of the panel.
    public static func backdropHeight(rows: Int) -> CGFloat {
        let cards = rows > 0 ? rowGap + height(rows: rows) : 0
        return min(2 * halo + rowHeight + cards + hintBlock, panelHeight)
    }

    public static func corner(for size: SpotSize) -> CGFloat {
        size.rows == 1 && size.columns < columns ? rowHeight / 2 : radius
    }

    /// Where the grid's first row starts: under the field, one gap down.
    public static let gridTop: CGFloat = halo + rowHeight + rowGap

    /// Where the grid's top left corner lies in the panel, with the grid scrolled this far.
    public static func gridOrigin(scrollOffset: CGFloat) -> CGPoint {
        CGPoint(x: halo, y: gridTop - scrollOffset)
    }
}
