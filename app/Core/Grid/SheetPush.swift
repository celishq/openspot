import Foundation

public struct SheetPush: Equatable, Sendable {
    public let open: SpotPlacement
    public let sheet: CGRect
    public let window: CGRect

    public init(open: SpotPlacement, sheet: CGRect, window: CGRect) {
        self.open = open
        self.sheet = sheet
        self.window = window
    }

    public func offset(of placement: SpotPlacement) -> CGSize {
        let from = open.rect
        let rect = placement.rect
        if rect.maxX <= sheet.minX || rect.minX >= sheet.maxX { return .zero }
        let away = placement.direction(awayFrom: open)
        return CGSize(
            width: away.columns < 0 ? sheet.minX - from.minX : away.columns > 0 ? sheet.maxX - from.maxX : 0,
            height: away.rows < 0 ? sheet.minY - from.minY : away.rows > 0 ? sheet.maxY - from.maxY : 0
        )
    }

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
