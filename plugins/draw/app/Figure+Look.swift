import AppKit

/// The colours and the fonts that a figure is drawn with.
extension Figure.Ink {
    var color: NSColor {
        switch self {
        case .black: NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)
        case .red: NSColor(srgbRed: 0.93, green: 0.27, blue: 0.27, alpha: 1)
        case .blue: NSColor(srgbRed: 0.18, green: 0.45, blue: 0.96, alpha: 1)
        case .orange: NSColor(srgbRed: 0.97, green: 0.54, blue: 0.12, alpha: 1)
        case .green: NSColor(srgbRed: 0.13, green: 0.66, blue: 0.40, alpha: 1)
        case .yellow: NSColor(srgbRed: 0.96, green: 0.76, blue: 0.10, alpha: 1)
        case .violet: NSColor(srgbRed: 0.62, green: 0.33, blue: 0.90, alpha: 1)
        case .grey: NSColor(srgbRed: 0.58, green: 0.60, blue: 0.64, alpha: 1)
        }
    }

    /// The light tint that fills a filled box.
    var tint: NSColor {
        color.blended(withFraction: 0.82, of: .white) ?? color
    }
}

extension Figure {
    /// The font of a text figure, or of the label inside a box.
    var font: NSFont {
        let size: CGFloat = switch weight {
        case .s: kind == .text ? 18 : 15
        case .m: kind == .text ? 24 : 19
        case .l: kind == .text ? 36 : 26
        }
        let base = NSFont.systemFont(ofSize: size, weight: .medium)
        guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: rounded, size: size) ?? base
    }

    /// The words of a figure as they are drawn.
    var words: NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = kind == .text ? .left : .center
        return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: ink.color, .paragraphStyle: style])
    }
}

extension Figure.Form {
    /// The symbol of a form in the toolbar and the shape picker.
    var symbol: String {
        switch self {
        case .rectangle: "square"
        case .ellipse: "circle"
        case .triangle: "triangle"
        case .diamond: "diamond"
        case .hexagon: "hexagon"
        case .oval: "capsule.portrait"
        case .parallelogram: "parallelogram"
        case .star: "star"
        case .cloud: "cloud"
        case .heart: "heart"
        case .xBox: "xmark.square"
        case .checkBox: "checkmark.square"
        case .arrowLeft: "arrowshape.left"
        case .arrowUp: "arrowshape.up"
        case .arrowDown: "arrowshape.down"
        case .arrowRight: "arrowshape.right"
        }
    }

    var title: String {
        switch self {
        case .xBox: "Crossed box"
        case .checkBox: "Checked box"
        case .arrowLeft: "Arrow left"
        case .arrowUp: "Arrow up"
        case .arrowDown: "Arrow down"
        case .arrowRight: "Arrow right"
        default: rawValue.capitalized
        }
    }
}
