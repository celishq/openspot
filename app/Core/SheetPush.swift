import Foundation

/// How an open sheet moves the other cards of the grid. Each card is pushed away from the sheet's card as far as the
/// sheet's edge on its side moves, and fades as it crosses the window's edge.
public struct SheetPush: Equatable, Sendable {
    /// The card that the sheet grows from.
    public let open: SpotPlacement
    /// The sheet's rect, in the grid.
    public let sheet: CGRect
    /// The rect of the window, in the grid.
    public let window: CGRect

    public init(open: SpotPlacement, sheet: CGRect, window: CGRect) {
        self.open = open
        self.sheet = sheet
        self.window = window
    }

    /// How far the open sheet pushes a card.
    public func offset(of placement: SpotPlacement) -> CGSize {
        let away = placement.direction(awayFrom: open)
        let from = open.rect
        return CGSize(
            width: away.columns < 0 ? sheet.minX - from.minX : away.columns > 0 ? sheet.maxX - from.maxX : 0,
            height: away.rows < 0 ? sheet.minY - from.minY : away.rows > 0 ? sheet.maxY - from.maxY : 0
        )
    }

    /// The shares of the sheet's motion over which a card fades and shrinks: from its start until the card's centre meets
    /// the window's edge, or the whole motion for a card that stays in the window. The sheet's own card never fades.
    public func fade(of placement: SpotPlacement) -> ClosedRange<Double> {
        guard placement.index != open.index else { return 1...1 }
        return CardPush(from: placement.rect, by: offset(of: placement)).fade(within: window) ?? 0...1
    }
}
