import CoreGraphics
import Foundation

/// One thing drawn on a board: a box, a line, an arrow, a stroke of the pen, a text, or the junction of a bundle.
/// A box and a text keep two corners in `points`, a line and an arrow their two ends, a pen each point it passed,
/// and a junction its centre. An arrow end can hold a figure, and then it follows that figure.
struct Figure: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case rectangle, ellipse, arrow, line, pen, text, junction
    }

    /// A colour of ink, in the order of the swatches, warm and cool in turn.
    enum Ink: String, Codable, CaseIterable {
        case black, red, blue, orange, green, yellow, violet, grey
    }

    enum Weight: String, Codable, CaseIterable {
        case s, m, l

        var width: CGFloat {
            switch self {
            case .s: 2
            case .m: 3.5
            case .l: 6
            }
        }
    }

    var id = UUID()
    var kind: Kind
    var points: [CGPoint]
    var ink = Ink.black
    var weight = Weight.m
    var dashed = false
    var filled = false
    var text = ""
    /// How far the middle of an arrow leaves the straight line, to its left when positive.
    var bend: CGFloat = 0
    /// The figure that holds the start of an arrow.
    var start: UUID?
    /// The figure that holds the end of an arrow.
    var end: UUID?

    var isBox: Bool {
        kind == .rectangle || kind == .ellipse || kind == .text
    }

    var isLink: Bool {
        kind == .arrow || kind == .line
    }

    /// The rectangle between the two corners of a box.
    var frame: CGRect {
        guard let first = points.first, let last = points.last else { return .zero }
        return CGRect(x: min(first.x, last.x), y: min(first.y, last.y), width: abs(last.x - first.x), height: abs(last.y - first.y))
    }

    /// Whether a point lies inside the outline of a box, grown by `pad`.
    func holds(_ point: CGPoint, pad: CGFloat = 0) -> Bool {
        let box = frame.insetBy(dx: -pad, dy: -pad)
        switch kind {
        case .ellipse:
            guard box.width > 0, box.height > 0 else { return false }
            let x = (point.x - box.midX) / (box.width / 2)
            let y = (point.y - box.midY) / (box.height / 2)
            return x * x + y * y <= 1
        case .rectangle, .text:
            return box.contains(point)
        default:
            return false
        }
    }
}
