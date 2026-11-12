import CoreGraphics
import Foundation

/// One thing drawn on a board: a shape, an arrow, a stroke of the pen, a text, an image, or a tie that holds arrows
/// together. A shape, a text and an image keep two corners in `points`, an arrow its two ends, a pen each point it passed,
/// and a tie its centre. An arrow end can hold a shape, and then it follows that shape.
struct Figure: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case shape, arrow, pen, text, image, tie
    }

    /// Where the lines of words sit across their box.
    enum Align: String, Codable, CaseIterable {
        case left, center, right
    }

    /// Where the words sit up and down their box.
    enum Place: String, Codable, CaseIterable {
        case top, middle, bottom
    }

    /// The outline of a shape, in the order of the shape picker.
    enum Form: String, Codable, CaseIterable {
        case rectangle, ellipse, triangle, diamond, hexagon, oval, parallelogram, star
        case cloud, heart, xBox, checkBox, arrowLeft, arrowUp, arrowDown, arrowRight
    }

    /// The ends of an arrow that carry a head.
    enum Heads: String, Codable, CaseIterable {
        case none, end, both
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
    var form = Form.rectangle
    var heads = Heads.end
    var ink = Ink.black
    var weight = Weight.m
    var dashed = false
    var filled = false
    var text = ""
    var align = Align.center
    var place = Place.middle
    /// The file name of an image, in the folder of the board's images.
    var source = ""
    /// How far the middle of an arrow leaves the straight line, to its left when positive.
    var bend: CGFloat = 0
    /// The shape that holds the start of an arrow.
    var start: UUID?
    /// The shape that holds the end of an arrow.
    var end: UUID?
    /// The ties that an arrow passes through, from its start to its end.
    var ties: [UUID] = []
    /// The arrows that a tie holds, side by side in this order.
    var members: [UUID] = []

    init(kind: Kind, points: [CGPoint]) {
        self.kind = kind
        self.points = points
        if kind == .text {
            align = .left
            place = .top
        }
    }

    var isBox: Bool {
        kind == .shape || kind == .text || kind == .image
    }

    /// The rectangle between the two corners of a shape.
    var frame: CGRect {
        guard let first = points.first, let last = points.last else { return .zero }
        return CGRect(x: min(first.x, last.x), y: min(first.y, last.y), width: abs(last.x - first.x), height: abs(last.y - first.y))
    }

    /// Whether a point lies inside the outline of a shape or text, grown by `pad`.
    func holds(_ point: CGPoint, pad: CGFloat = 0) -> Bool {
        let box = frame.insetBy(dx: -pad, dy: -pad)
        switch kind {
        case .text, .image: return box.contains(point)
        case .shape: return box.width > 0 && box.height > 0 && form.path(in: box).contains(point)
        default: return false
        }
    }

    // MARK: File

    private enum Key: String, CodingKey {
        case id, kind, points, form, heads, ink, weight, dashed, filled, text, align, place, source, bend, start, end, ties, members
    }

    /// Reads a figure, also one of an older board: a rectangle or an ellipse is a shape, a line is an arrow with no head,
    /// and a junction is a tie whose arrows the board finds.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: Key.self)
        id = try values.decode(UUID.self, forKey: .id)
        points = try values.decode([CGPoint].self, forKey: .points)
        let name = try values.decode(String.self, forKey: .kind)
        switch name {
        case "rectangle", "ellipse":
            kind = .shape
            form = Form(rawValue: name) ?? .rectangle
        case "line":
            kind = .arrow
            heads = .none
        case "junction":
            kind = .tie
        default:
            guard let known = Kind(rawValue: name) else {
                throw DecodingError.dataCorruptedError(forKey: .kind, in: values, debugDescription: "Unknown kind \(name)")
            }
            kind = known
        }
        form = try values.decodeIfPresent(Form.self, forKey: .form) ?? form
        heads = try values.decodeIfPresent(Heads.self, forKey: .heads) ?? heads
        ink = try values.decodeIfPresent(Ink.self, forKey: .ink) ?? (kind == .tie ? .blue : .black)
        weight = try values.decodeIfPresent(Weight.self, forKey: .weight) ?? .m
        dashed = try values.decodeIfPresent(Bool.self, forKey: .dashed) ?? false
        filled = try values.decodeIfPresent(Bool.self, forKey: .filled) ?? false
        text = try values.decodeIfPresent(String.self, forKey: .text) ?? ""
        align = try values.decodeIfPresent(Align.self, forKey: .align) ?? (kind == .text ? .left : .center)
        place = try values.decodeIfPresent(Place.self, forKey: .place) ?? (kind == .text ? .top : .middle)
        source = try values.decodeIfPresent(String.self, forKey: .source) ?? ""
        bend = try values.decodeIfPresent(CGFloat.self, forKey: .bend) ?? 0
        start = try values.decodeIfPresent(UUID.self, forKey: .start)
        end = try values.decodeIfPresent(UUID.self, forKey: .end)
        ties = try values.decodeIfPresent([UUID].self, forKey: .ties) ?? []
        members = try values.decodeIfPresent([UUID].self, forKey: .members) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: Key.self)
        try values.encode(id, forKey: .id)
        try values.encode(kind, forKey: .kind)
        try values.encode(points, forKey: .points)
        if kind == .shape { try values.encode(form, forKey: .form) }
        if kind == .arrow { try values.encode(heads, forKey: .heads) }
        try values.encode(ink, forKey: .ink)
        try values.encode(weight, forKey: .weight)
        if dashed { try values.encode(dashed, forKey: .dashed) }
        if filled { try values.encode(filled, forKey: .filled) }
        if !text.isEmpty { try values.encode(text, forKey: .text) }
        if kind == .text || kind == .shape {
            try values.encode(align, forKey: .align)
            try values.encode(place, forKey: .place)
        }
        if !source.isEmpty { try values.encode(source, forKey: .source) }
        if bend != 0 { try values.encode(bend, forKey: .bend) }
        try values.encodeIfPresent(start, forKey: .start)
        try values.encodeIfPresent(end, forKey: .end)
        if !ties.isEmpty { try values.encode(ties, forKey: .ties) }
        if !members.isEmpty { try values.encode(members, forKey: .members) }
    }
}
