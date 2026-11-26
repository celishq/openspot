import Foundation

extension HexColor {
    public struct Format: Equatable, Sendable {
        public let id: String
        public let title: String
        public let text: String
    }

    static let peekID = "color"
    static let copyAs = "copy-as"
    static let cssLimit = 64

    public init?(css: String) {
        let value = css.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.first == "#" {
            var digits = String(value.dropFirst())
            guard [3, 6, 8].contains(digits.count), digits.allSatisfy(\.isHexDigit) else { return nil }
            if digits.count == 3 { digits = digits.map { "\($0)\($0)" }.joined() }
            self.init(text: "#" + digits)
            return
        }
        guard let open = value.firstIndex(of: "("), value.hasSuffix(")") else { return nil }
        let name = value[..<open]
        let parts = value[value.index(after: open)..<value.index(before: value.endIndex)]
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "/" })
            .map(String.init)
        guard parts.count >= 3 else { return nil }
        let number = { (part: String, scale: Double) -> Double? in
            part.hasSuffix("%") ? Double(part.dropLast()).map { $0 / 100 * scale } : Double(part)
        }
        let alpha = parts.count > 3 ? number(parts[3], 1) : 1
        guard let alpha else { return nil }
        switch name {
        case "rgb", "rgba":
            guard let r = number(parts[0], 255), let g = number(parts[1], 255), let b = number(parts[2], 255) else { return nil }
            self.init(red: r / 255, green: g / 255, blue: b / 255, alpha: alpha)
        case "hsl", "hsla":
            guard let h = Double(parts[0].replacingOccurrences(of: "deg", with: "")), let s = number(parts[1], 1), let l = number(parts[2], 1) else { return nil }
            let q = l < 0.5 ? l * (1 + s) : l + s - l * s
            let p = 2 * l - q
            let channel = { (shift: Double) -> Double in
                var t = (h / 360 + shift).truncatingRemainder(dividingBy: 1)
                if t < 0 { t += 1 }
                if t < 1 / 6 { return p + (q - p) * 6 * t }
                if t < 1 / 2 { return q }
                if t < 2 / 3 { return p + (q - p) * (2 / 3 - t) * 6 }
                return p
            }
            self.init(red: channel(1 / 3), green: channel(0), blue: channel(-1 / 3), alpha: alpha)
        default:
            return nil
        }
    }

    public var formats: [Format] {
        let channels = [red, green, blue].map { Int(($0 * 255).rounded()) }
        let rgb = channels.map(String.init)
        let opacity = alpha == 1 ? "1" : String(format: "%.2g", alpha)
        let shade = hsl
        let swift = String(format: "Color(red: %.3f, green: %.3f, blue: %.3f", red, green, blue) + (alpha == 1 ? ")" : String(format: ", opacity: %.3f)", alpha))
        return [
            Format(id: "hex", title: "HEX", text: text),
            Format(id: "rgb", title: "RGB", text: "rgb(\(rgb.joined(separator: " ")))"),
            Format(id: "rgba", title: "RGBA", text: "rgba(\(rgb.joined(separator: ", ")), \(opacity))"),
            Format(id: "hsl", title: "HSL", text: "hsl(\(shade.hue) \(shade.saturation)% \(shade.lightness)%)"),
            Format(id: "swiftui", title: "SwiftUI", text: swift),
        ]
    }

    public var peek: [TextBlock] {
        let field = { (key: String, value: String) in TextBlock.Field(key: key, value: value) }
        let parent = field(ViewNode.parentKey, Self.peekID)
        let shown = formats
        var blocks = [
            TextBlock(fields: [field(BlockKind.peek.word, Self.peekID), field(ViewNode.classKey, "flex-col gap-part")]),
            TextBlock(fields: [field(BlockKind.icon.word, "swatch"), parent, field("value", String(text.lowercased().prefix(7)))]),
        ]
        blocks += shown.filter { $0.id != "rgba" && $0.id != "swiftui" }.map { TextBlock(fields: [field(BlockKind.text.word, $0.id), parent, field("title", $0.text)] + ($0.id == "hex" ? [field(ViewNode.classKey, "font-title")] : [])) }
        blocks.append(TextBlock(fields: [field(BlockKind.button.word, Self.copyAs), parent, field("title", "Copy as")]))
        blocks += shown.map { TextBlock(fields: [field(BlockKind.button.word, "\(Self.copyAs).\($0.id)"), parent, field("title", $0.title), field("copy", $0.text)]) }
        return blocks
    }

    private var hsl: (hue: Int, saturation: Int, lightness: Int) {
        let high = max(red, green, blue)
        let low = min(red, green, blue)
        let lightness = (high + low) / 2
        let spread = high - low
        guard spread > 0 else { return (0, 0, Int((lightness * 100).rounded())) }
        let saturation = spread / (1 - abs(2 * lightness - 1))
        let sector: Double = switch high {
        case red: (green - blue) / spread
        case green: (blue - red) / spread + 2
        default: (red - green) / spread + 4
        }
        var hue = 60 * sector
        if hue < 0 { hue += 360 }
        return (Int(hue.rounded()) % 360, Int((saturation * 100).rounded()), Int((lightness * 100).rounded()))
    }
}
