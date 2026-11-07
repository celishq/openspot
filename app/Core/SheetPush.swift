import Foundation

/// How an open sheet moves the other cards of the grid. Each card is pushed away from the sheet's card as far as the
/// sheet's edge on its side moves, and fades as it crosses the window's edge.
public struct SheetPush: Equatable, Sendable {
    /// How far past the sheet's rect a card may go before it is gone.
    public static let reach = SpotTokens.halo / 3

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

    /// The shares of the sheet's motion over which a card fades: from when its leading edge meets the window's edge until
    /// its centre does. A card that stays in the window fades once it has gone past the sheet's rect, and the sheet's own
    /// card never fades.
    public func fade(of placement: SpotPlacement) -> ClosedRange<Double> {
        guard placement.index != open.index else { return 1...1 }
        let push = CardPush(from: placement.rect, by: offset(of: placement))
        if let fade = push.fade(within: window) { return fade }
        return push.exit(from: sheet.insetBy(dx: -Self.reach, dy: -Self.reach))...1
    }

    /// How many cells lie from the open card to the nearest cell of a card, across or along the grid.
    public func ring(of placement: SpotPlacement) -> Int {
        func gap(_ start: Int, _ length: Int, _ openStart: Int, _ openLength: Int) -> Int {
            max(openStart - (start + length - 1), start - (openStart + openLength - 1), 0)
        }
        return max(
            gap(placement.column, placement.size.columns, open.column, open.size.columns),
            gap(placement.row, placement.size.rows, open.row, open.size.rows)
        )
    }
}
