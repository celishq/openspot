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

    /// How far the open sheet pushes a card. A card that lies wholly beside the sheet's columns, on a wide grid, moves only to
    /// its side.
    public func offset(of placement: SpotPlacement) -> CGSize {
        let from = open.rect
        let rect = placement.rect
        if rect.maxX <= sheet.minX { return CGSize(width: sheet.minX - from.minX, height: 0) }
        if rect.minX >= sheet.maxX { return CGSize(width: sheet.maxX - from.maxX, height: 0) }
        let away = placement.direction(awayFrom: open)
        return CGSize(
            width: away.columns < 0 ? sheet.minX - from.minX : away.columns > 0 ? sheet.maxX - from.maxX : 0,
            height: away.rows < 0 ? sheet.minY - from.minY : away.rows > 0 ? sheet.maxY - from.maxY : 0
        )
    }

    /// How far a card that has moved this far has faded and shrunk, from 0 to 1: the share of its way from its place until
    /// its centre meets the window's edge, or of its whole push when it stays in the window. Nil for a card that the push
    /// leaves in place, and 0 for the sheet's own card.
    public func fade(of placement: SpotPlacement, movedBy moved: CGSize) -> Double? {
        guard placement.index != open.index else { return 0 }
        let push = offset(of: placement)
        let length = (push.width * push.width + push.height * push.height).squareRoot()
        guard length > 0 else { return nil }
        let along = (moved.width * push.width + moved.height * push.height) / length
        let end = CardPush(from: placement.rect, by: push).fade(within: window)?.upperBound ?? 1
        guard end > 0 else { return 1 }
        return min(max(Double(along / length) / end, 0), 1)
    }
}
