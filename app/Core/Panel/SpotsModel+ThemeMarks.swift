import Foundation

extension SpotsModel {
    public func themeMarks() -> ThemeMarks {
        let sheet = formRect ?? openSheetID.flatMap { sheets[$0]?.sheetRect }
        let cards = placements.map { placement in
            (placement: placement, isPadded: !(visible.indices.contains(placement.index) && visible[placement.index].kind == .widget && placement.size == .small))
        }
        return ThemeMarks(sizes: SpotTokens.sizes, cards: cards, scroll: gridScroll, sheet: sheet)
    }
}
