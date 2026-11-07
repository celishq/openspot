import Foundation

/// How an open sheet moves the other cards of the grid. Each card is pushed away from the sheet's card as far as the
/// sheet's edge on its side moves, and fades by the time it goes further past the sheet than the backdrop's tint reaches.
public struct SheetPush: Equatable, Sendable {
    /// How far past the sheet's rect a card may go before it is gone.
    public static let reach = SpotTokens.halo / 3

    /// The card that the sheet grows from.
    public let open: SpotPlacement
    /// The sheet's rect, in the grid.
    public let sheet: CGRect

    public init(open: SpotPlacement, sheet: CGRect) {
        self.open = open
        self.sheet = sheet
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

    /// The share of the sheet's motion at which a card has gone past the reach of the tint; 1 for the sheet's own card and
    /// for one that never goes so far.
    public func exit(of placement: SpotPlacement) -> Double {
        guard placement.index != open.index else { return 1 }
        let shown = sheet.insetBy(dx: -Self.reach, dy: -Self.reach)
        return CardPush(from: placement.rect, by: offset(of: placement)).exit(from: shown)
    }
}
