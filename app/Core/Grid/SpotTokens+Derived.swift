import Foundation

extension SpotTokens {
    public static var cell: CGFloat { sizes.cell }

    public static let groupTitleBand: CGFloat = groupTitleHeight + placeGap

    public static let rimPoint: CGFloat = 1 - 0.5.squareRoot()

    public static let hintKeyInset: CGFloat = hintHeight / 2 + hintPillInset - hintKeyHeight / 2

    public static let hintPillHeight: CGFloat = hintHeight + 2 * hintPillInset

    public static var hintBlock: CGFloat { sizes.hintBlock }

    public static var panelWidth: CGFloat { sizes.panelWidth }

    public static var panelHeight: CGFloat { sizes.panelHeight }

    public static var sheetMaxHeight: CGFloat { sizes.sheetMaxHeight }

    public static var sheetFieldDrop: CGFloat { sizes.sheetFieldDrop }

    public static func width(columns: Int) -> CGFloat {
        CGFloat(columns) * cell + CGFloat(columns - 1) * columnGap
    }

    public static func height(rows: Int) -> CGFloat {
        CGFloat(rows) * rowHeight + CGFloat(rows - 1) * rowGap
    }

    public static func cardPadding(for size: SpotSize, isWidget: Bool) -> CGFloat {
        isWidget && size == .small ? controlPadding : padding
    }

    public static func pictureSide(in room: CGSize) -> CGFloat {
        let fit = min(room.width, room.height)
        return min(fit, room.height <= listRowHeight ? listIconSize : fit * pictureShare)
    }

    public static var sheetRowsTop: CGFloat { sizes.sheetRowsTop }

    public static func square(perLine: Int) -> CGFloat {
        (SheetPlacement.width - listRowGap * CGFloat(perLine - 1)) / CGFloat(perLine)
    }

    public static func sheetRect(rows: Int, perLine: Int = 1, hasField: Bool = true, setsApart: Bool = false) -> CGRect {
        let lines = CGFloat(max((rows + perLine - 1) / perLine, 1))
        let line = perLine > 1 ? square(perLine: perLine) : listRowHeight
        let height = sheetRowsTop - (hasField ? 0 : listRowHeight + rowGap) + lines * line + (lines - 1) * listRowGap + padding
            + (setsApart ? pinRuleRoom + listRowGap : 0)
        return CGRect(x: halo, y: halo, width: gridWidth, height: min(height, sheetMaxHeight))
    }

    public static func firstScreen(perLine: Int) -> Int {
        let line = perLine > 1 ? square(perLine: perLine) : listRowHeight
        let lines = ((sheetMaxHeight - sheetRowsTop - padding) / (line + listRowGap)).rounded(.up)
        return (Int(lines) + 1) * max(perLine, 1)
    }

    public static var windowSize: CGSize { CGSize(width: width(columns: windowColumns) + 2 * padding, height: windowHeight) }

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

    public static func sheetFits(rows: Int, perLine: Int = 1) -> Bool {
        sheetRect(rows: rows, perLine: perLine).height < sheetMaxHeight
    }

    public static func panelRect(_ panel: SheetParts) -> CGRect {
        let field = panel.showsRows ? SheetPlacement.fieldRoom : 0
        let height = padding + glyphSize + rowGap + field + panel.placement.height + padding
        return CGRect(x: halo, y: halo, width: gridWidth, height: min(height, sheetMaxHeight))
    }

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

    public static func contentHeight(gridHeight: CGFloat) -> CGFloat {
        let cards = gridHeight > 0 ? rowGap + gridHeight : 0
        return min(2 * halo + rowHeight + cards + hintBlock, panelHeight)
    }

    static func corner(for size: SpotSize) -> CGFloat {
        size.rows == 1 && size.columns < columns ? min(rowHeight / 2 * radius / SpotTokens.builtIn.radius, rowHeight / 2) : radius
    }

    public static var gridTop: CGFloat { sizes.gridTop }

    public static func gridOrigin(scrollOffset: CGFloat, left: CGFloat) -> CGPoint {
        CGPoint(x: halo - left, y: gridTop - scrollOffset)
    }

    public static var menuTextInset: CGFloat { padding - menuPadding + 4 }
    public static var wordsGap: CGFloat { padding - 5 }
    public static var formInset: CGFloat { padding - 5 }
    public static var arrowRowInset: CGFloat { padding - 6 }

    public static var toastRadius: CGFloat { rowHeight / 3 }
    public static var playgroundTopIdeal: CGFloat { panelHeight + 120 }
    public static var playgroundStageWidth: CGFloat { gridWidth + 2 * padding }
}
