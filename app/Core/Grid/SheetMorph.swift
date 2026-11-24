import CoreGraphics
import Foundation

public struct SheetMorph: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        case card
        case field
    }

    public let card: CGRect
    public let sheet: CGRect
    public let source: Source

    public static var clearance: CGFloat { SpotTokens.padding }

    public init(card: CGRect, sheet: CGRect, source: Source = .card) {
        self.card = card
        self.sheet = sheet
        self.source = source
    }

    public func foot(at progress: Double) -> CGFloat {
        origin(at: progress).y + size(at: progress).height + SpotTokens.halo + SpotTokens.hintBlock
    }

    public func headerOpacity(at progress: Double) -> Double {
        source == .field ? Self.sheetOpacity(at: progress) : 1
    }

    public func sourceOpacity(at progress: Double) -> Double {
        source == .field ? 0 : Self.cardOpacity(at: progress)
    }

    public func size(at progress: Double) -> CGSize {
        let t = CGFloat(progress)
        return CGSize(width: card.width + (sheet.width - card.width) * t, height: card.height + (sheet.height - card.height) * t)
    }

    public static func cardOpacity(at progress: Double) -> Double {
        1 - ease(progress / MotionTokens.cardShare)
    }

    public static func sheetOpacity(at progress: Double) -> Double {
        ease((progress - MotionTokens.contentStart) / (1 - MotionTokens.contentStart))
    }

    public static func contentOpacity(at progress: Double, isOpen: Bool) -> Double {
        guard isOpen else { return progress }
        return 1 - pow(1 - sheetOpacity(at: progress), 1 / MotionTokens.contentSoftness)
    }

    public func origin(at progress: Double) -> CGPoint {
        let t = CGFloat(progress)
        return CGPoint(x: card.minX + (sheet.minX - card.minX) * t, y: card.minY + (sheet.minY - card.minY) * t)
    }

    public func wordsOpacity(of words: CGRect, header: CGRect, at progress: Double) -> Double {
        let corner = origin(at: progress)
        let placed = header.offsetBy(dx: corner.x, dy: corner.y)
        let gap = max(words.minY - placed.maxY, placed.minY - words.maxY)
        return 1 - headerOpacity(at: progress) * (1 - Self.depth(gap))
    }

    public func fieldGlassOpacity(of field: CGRect, at progress: Double) -> Double {
        guard source == .card else { return 0 }
        let room = CGRect(origin: origin(at: progress), size: size(at: progress))
        return 1 - Self.depth(min(field.minX - room.minX, field.minY - room.minY, room.maxX - field.maxX, room.maxY - field.maxY))
    }

    public static func place(onCard: CGSize, at progress: Double) -> CGSize {
        let left = CGFloat(1 - progress)
        return CGSize(width: onCard.width * left, height: onCard.height * left)
    }

    public func edgeOpacity(of part: CGRect, at progress: Double) -> Double {
        let room = size(at: progress)
        return Self.depth(min(room.width - part.maxX, room.height - part.maxY))
    }

    public func middleOpacity(of part: CGRect, at progress: Double) -> Double {
        let room = size(at: progress)
        let across = part.width > 0 ? Double((room.width - part.midX) / (part.width / 2)) : 1
        let down = part.height > 0 ? Double((room.height - part.midY) / (part.height / 2)) : 1
        return min(max(min(across, down), 0), 1)
    }

    private static func depth(_ inset: CGFloat) -> Double {
        ease(Double(inset / clearance))
    }

    static func ease(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }
}
