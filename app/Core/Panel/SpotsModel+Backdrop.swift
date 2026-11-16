import Foundation

extension SpotsModel {
    public var backdrop: CGRect {
        let foot = backdropFoot
        let span = backdropPanels.frame
        return CGRect(x: span.minX, y: 0, width: span.width, height: transition.isOpen ? foot.open : foot.closed)
    }

    public var backdropFoot: SheetPush.Foot {
        let sheet = formRect ?? backdropSheet?.sheetRect ?? SpotTokens.sheetRect(rows: 0)
        let open = sheet.height + 2 * SpotTokens.halo + SpotTokens.hintBlock + flowEdges.heldHeight(of: sheet)
        return SheetPush.Foot(closed: max(gridHeight, menuContentHeight), open: max(open, menuContentHeight))
    }

    func spanBackdrop() {
        let shown = query.isEmpty ? panels : GridPanels()
        if shown != backdropPanels { backdropPanels = shown }
    }

    func holdBackdropSheet() {
        let sheet = transition.id.flatMap { sheets[$0] }
        if sheet !== backdropSheet { backdropSheet = sheet }
    }
}
