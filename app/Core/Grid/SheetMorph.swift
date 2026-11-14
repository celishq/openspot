import CoreGraphics
import Foundation

public struct SheetMorph: Equatable, Sendable {
    public let card: CGRect
    public let sheet: CGRect

    public static let clearance = SpotTokens.padding

    public init(card: CGRect, sheet: CGRect) {
        self.card = card
        self.sheet = sheet
    }

    public func size(at progress: Double) -> CGSize {
        let t = CGFloat(progress)
        return CGSize(width: card.width + (sheet.width - card.width) * t, height: card.height + (sheet.height - card.height) * t)
    }

    public static func cardLook(at progress: Double) -> Double {
        1 - ease(progress / MotionTokens.cardShare)
    }

    public static func sheetLook(at progress: Double) -> Double {
        ease((progress - MotionTokens.cardShare) / (1 - MotionTokens.cardShare))
    }

    public func origin(at progress: Double) -> CGPoint {
        let t = CGFloat(progress)
        return CGPoint(x: card.minX + (sheet.minX - card.minX) * t, y: card.minY + (sheet.minY - card.minY) * t)
    }

    public func crossing(of words: CGRect, header: CGRect, at progress: Double) -> Double {
        let corner = origin(at: progress)
        let placed = header.offsetBy(dx: corner.x, dy: corner.y)
        let gap = max(words.minY - placed.maxY, placed.minY - words.maxY)
        return Self.ease(Double(gap / Self.clearance))
    }

    public static func place(onCard: CGSize, at progress: Double) -> CGSize {
        let left = CGFloat(1 - progress)
        return CGSize(width: onCard.width * left, height: onCard.height * left)
    }

    public func shown(_ part: CGRect, at progress: Double) -> Double {
        let room = size(at: progress)
        let past = min(room.width - part.maxX, room.height - part.maxY)
        return Self.ease(Double(past / Self.clearance))
    }

    public func growth(of part: CGRect, at progress: Double) -> Double {
        let room = size(at: progress)
        let across = part.width > 0 ? Double((room.width - part.midX) / (part.width / 2)) : 1
        let down = part.height > 0 ? Double((room.height - part.midY) / (part.height / 2)) : 1
        return min(max(min(across, down), 0), 1)
    }

    static func ease(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }
}
