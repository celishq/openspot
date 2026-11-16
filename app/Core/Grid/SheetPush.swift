import Foundation

public struct SheetPush: Equatable, Sendable {
    public struct Foot: Equatable, Sendable {
        public let closed: CGFloat
        public let open: CGFloat

        public init(closed: CGFloat, open: CGFloat) {
            self.closed = closed
            self.open = open
        }

        func meeting(of rect: CGRect, movingDown move: CGFloat) -> Double? {
            guard rect.maxY < closed else { return 0 }
            let closing = move - (open - closed)
            guard closing > 0 else { return nil }
            return min(Double((closed - rect.maxY) / closing), 1)
        }
    }

    public let open: SpotPlacement?
    public let sheet: CGRect
    public let window: CGRect
    public let foot: Foot?

    public init(open: SpotPlacement?, sheet: CGRect, window: CGRect, foot: Foot? = nil) {
        self.open = open
        self.sheet = sheet
        self.window = window
        self.foot = foot
    }

    public func offset(of placement: SpotPlacement) -> CGSize {
        guard let open else { return .zero }
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
        guard let open else { return nil }
        guard placement.index != open.index else { return 0 }
        let push = offset(of: placement)
        let length = (push.width * push.width + push.height * push.height).squareRoot()
        guard length > 0 else { return nil }
        let along = (moved.width * push.width + moved.height * push.height) / length
        let ends = [CardPush(from: placement.rect, by: push).fade(within: window)?.upperBound, foot?.meeting(of: placement.rect, movingDown: push.height)]
        let end = ends.compactMap { $0 }.min() ?? 1
        guard end > 0 else { return 1 }
        return min(max(Double(along / length) / end, 0), 1)
    }

    public func fade(of placement: SpotPlacement, share: Double) -> Double {
        guard let meeting = foot?.meeting(of: placement.rect, movingDown: 0) else { return share }
        guard meeting > 0 else { return 1 }
        return min(share / meeting, 1)
    }
}
