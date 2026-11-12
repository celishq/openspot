import CoreGraphics
import Foundation

/// The look of a sheet at one point of its motion between its card and its open place, read from its progress: 0 on the
/// card and 1 open. Each part of the sheet takes its place, its fade and its size from the progress alone, so that no part
/// keeps a clock of its own. The content keeps the sheet's size, and its corner lies on the shape's corner.
public struct SheetMorph: Equatable, Sendable {
    /// Where the sheet lies on its card, and where it lies open.
    public let card: CGRect
    public let sheet: CGRect

    /// The share of the motion near the card in which the card's own look, such as its fill, gives way to the sheet's.
    public static let cardShare = 0.5
    /// How far past a part's far side the shape's edge lies when the part shows whole.
    public static let clearance = SpotTokens.padding

    public init(card: CGRect, sheet: CGRect) {
        self.card = card
        self.sheet = sheet
    }

    /// The shape's size at this progress, which is the room the content has.
    public func size(at progress: Double) -> CGSize {
        let t = CGFloat(progress)
        return CGSize(width: card.width + (sheet.width - card.width) * t, height: card.height + (sheet.height - card.height) * t)
    }

    /// How strongly a look of the card shows, such as the fill of a card that is on: whole on the card, gone half way.
    public static func cardLook(at progress: Double) -> Double {
        1 - ease(progress / cardShare)
    }

    /// How strongly a look of the open sheet shows that takes the place of one of the card's: none half way, whole open.
    public static func sheetLook(at progress: Double) -> Double {
        ease((progress - cardShare) / (1 - cardShare))
    }

    /// A place between a part's place on the card and its place in the sheet, as offsets from its place in the sheet.
    public static func place(onCard: CGSize, at progress: Double) -> CGSize {
        let left = CGFloat(1 - progress)
        return CGSize(width: onCard.width * left, height: onCard.height * left)
    }

    /// How strongly a part that the card has no place for shows: none until the shape's edge has passed the part's far
    /// side, so that the edge never cuts it, and whole once the edge lies `clearance` past it. The rect lies in the content.
    public func shown(_ part: CGRect, at progress: Double) -> Double {
        let room = size(at: progress)
        let past = min(room.width - part.maxX, room.height - part.maxY)
        return Self.ease(Double(past / Self.clearance))
    }

    /// The scale of a part that grows in place about its centre as the shape's edge reaches it, so that the edge never
    /// cuts it: 0 while the edge lies at its centre, and 1 once the edge has passed it.
    public func growth(of part: CGRect, at progress: Double) -> Double {
        let room = size(at: progress)
        let across = part.width > 0 ? Double((room.width - part.midX) / (part.width / 2)) : 1
        let down = part.height > 0 ? Double((room.height - part.midY) / (part.height / 2)) : 1
        return min(max(min(across, down), 0), 1)
    }

    /// A smooth step from 0 to 1, flat at both ends.
    static func ease(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }
}
