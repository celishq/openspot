import Foundation

public struct FlowEdge: Equatable, Identifiable, Sendable {
    public enum Side: Equatable, Sendable {
        case behind, ahead
    }

    public enum Place: Equatable, Sendable {
        case bar(Side, Int)
        case line(Side)
        case stand(CGRect)
        case sheet
    }

    public let sheet: FlowSheet
    public let title: String
    public internal(set) var place: Place
    public internal(set) var isFading = false

    public var id: FlowSheet {
        sheet
    }

    public func rect(around sheetRect: CGRect) -> CGRect {
        place.rect(around: sheetRect)
    }

    public var radius: CGFloat {
        SpotTokens.radius
    }
}

extension FlowEdge.Place {
    public func rect(around sheetRect: CGRect) -> CGRect {
        switch self {
        case .bar(let side, let index):
            let height = max(sheetRect.height - 2 * SpotTokens.radius - CGFloat(index) * SpotTokens.edgeShrink, SpotTokens.edgeWidth)
            let reach = SpotTokens.edgeGap + CGFloat(index) * (SpotTokens.edgeWidth + SpotTokens.edgeStep)
            let x = side == .behind ? sheetRect.minX - reach - SpotTokens.edgeWidth : sheetRect.maxX + reach
            return CGRect(x: x, y: sheetRect.midY - height / 2, width: SpotTokens.edgeWidth, height: height)
        case .line(let side):
            return Self.bar(side, 0).rect(around: sheetRect).insetBy(dx: SpotTokens.edgeWidth / 2, dy: 0)
        case .stand(let rect):
            return rect
        case .sheet:
            return sheetRect
        }
    }
}
