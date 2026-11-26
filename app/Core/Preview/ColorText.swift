import Foundation

enum ColorText {
    static func hex(of text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespaces).lowercased()
        if value.first == "#" {
            var digits = String(value.dropFirst())
            guard [3, 6, 8].contains(digits.count), digits.allSatisfy(\.isHexDigit) else { return nil }
            if digits.count == 3 { digits = digits.map { "\($0)\($0)" }.joined() }
            return "#" + digits.prefix(6)
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
        let red: Double, green: Double, blue: Double
        switch name {
        case "rgb", "rgba":
            guard let r = number(parts[0], 255), let g = number(parts[1], 255), let b = number(parts[2], 255) else { return nil }
            (red, green, blue) = (r, g, b)
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
            (red, green, blue) = (channel(1 / 3) * 255, channel(0) * 255, channel(-1 / 3) * 255)
        default:
            return nil
        }
        return "#" + [red, green, blue].map { String(format: "%02x", Int(min(max($0, 0), 255).rounded())) }.joined()
    }
}
