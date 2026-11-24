import Foundation

public struct SheetPush: Equatable, Sendable {
    public let open: SpotPlacement?
    public let sheet: CGRect
    public let window: CGRect
    public let foot: PanelFoot?

    public init(open: SpotPlacement?, sheet: CGRect, window: CGRect, foot: PanelFoot? = nil) {
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
        guard let (push, end) = fadeEnd(of: placement) else { return nil }
        guard end > 0 else { return 1 }
        return min(max(Double(share(of: moved, along: push)) / end, 0), 1)
    }

    public func pose(of placement: SpotPlacement, movedBy moved: CGSize) -> CGSize {
        guard let open, placement.index != open.index, let (push, end) = fadeEnd(of: placement) else { return moved }
        guard end > 0 else { return .zero }
        guard Double(share(of: moved, along: push)) >= end else { return moved }
        return CGSize(width: push.width * end, height: push.height * end)
    }

    private func fadeEnd(of placement: SpotPlacement) -> (push: CGSize, end: Double)? {
        let push = offset(of: placement)
        guard push != .zero else { return nil }
        let ends = [CardPush(from: placement.rect, by: push).fade(within: window)?.upperBound, foot?.meeting(of: placement.rect, movingDown: push.height)]
        return (push, ends.compactMap { $0 }.min() ?? 1)
    }

    private func share(of moved: CGSize, along push: CGSize) -> CGFloat {
        (moved.width * push.width + moved.height * push.height) / (push.width * push.width + push.height * push.height)
    }

    public func fade(of placement: SpotPlacement, share: Double) -> Double {
        guard let meeting = foot?.meeting(of: placement.rect, movingDown: 0) else { return share }
        guard meeting > 0 else { return 1 }
        return min(share / meeting, 1)
    }
}
