import Foundation

extension SpotsModel {
    public var backdrop: CGRect {
        let sheet = formRect ?? transition.id.flatMap { sheets[$0]?.sheetRect } ?? SpotTokens.sheetRect(rows: 0)
        let content = transition.isOpen ? sheet.height + 2 * SpotTokens.halo + SpotTokens.hintBlock + flowEdges.heldHeight(of: sheet) : gridHeight
        let span = (query.isEmpty ? panels : GridPanels()).frame
        return CGRect(x: span.minX, y: 0, width: span.width, height: max(content, menuContentHeight))
    }
}
