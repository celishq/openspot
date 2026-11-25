import Foundation

extension SpotsModel {
    public var backdrop: CGRect {
        let foot = panelFoot
        return CGRect(x: 0, y: 0, width: SpotTokens.panelWidth, height: transition.isOpen ? foot.open : foot.closed)
    }

    public var panelFoot: PanelFoot {
        let closed = max(gridHeight, menuContentHeight)
        let open = backdropSheetRect.map { Self.foot(of: $0) + flowEdges.heldHeight(of: $0) } ?? closed
        return PanelFoot(closed: closed, open: max(open, isMenuOpen ? menuContentHeight : 0))
    }

    public var pushFoot: PanelFoot {
        PanelFoot(closed: gridHeight, open: Self.foot(of: backdropSheetRect ?? SpotTokens.sheetRect(rows: 0)))
    }

    private var backdropSheetRect: CGRect? {
        formRect ?? backdropSheet?.sheetRect ?? (transition.id == nil ? nil : SpotTokens.sheetRect(rows: 0))
    }

    private static func foot(of sheet: CGRect) -> CGFloat {
        sheet.height + 2 * SpotTokens.halo + SpotTokens.hintBlock
    }

    func holdBackdropSheet() {
        let sheet = transition.id.flatMap { sheets[$0] }
        if sheet !== backdropSheet { backdropSheet = sheet }
    }
}
