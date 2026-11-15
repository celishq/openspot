import Foundation

extension SpotsModel {
    public var backdrop: CGRect {
        let sheet = formRect ?? backdropSheet?.sheetRect ?? SpotTokens.sheetRect(rows: 0)
        let content = transition.isOpen ? sheet.height + 2 * SpotTokens.halo + SpotTokens.hintBlock + flowEdges.heldHeight(of: sheet) : gridHeight
        let span = backdropPanels.frame
        return CGRect(x: span.minX, y: 0, width: span.width, height: max(content, menuContentHeight))
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
