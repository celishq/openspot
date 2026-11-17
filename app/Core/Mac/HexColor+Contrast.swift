import Foundation

extension HexColor {
    public var luminance: Double {
        Self.luminance(of: [red, green, blue])
    }

    public var lightness: Double {
        Self.lightness(of: [red, green, blue])
    }

    public func contrast(with other: HexColor) -> Double {
        let (one, two) = (luminance, other.luminance)
        return (max(one, two) + 0.05) / (min(one, two) + 0.05)
    }

    public func mixed(with other: HexColor, by share: Double) -> HexColor {
        let parts = Self.mix([red, green, blue], [other.red, other.green, other.blue], by: share)
        return HexColor(red: parts[0], green: parts[1], blue: parts[2])
    }

    public func with(alpha: Double) -> HexColor {
        HexColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    static func mix(_ one: [Double], _ other: [Double], by share: Double) -> [Double] {
        zip(one, other).map { $0 + ($1 - $0) * share }
    }

    static func luminance(of parts: [Double]) -> Double {
        let linear = parts.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }

    static func lightness(of parts: [Double]) -> Double {
        let y = luminance(of: parts)
        return y > 216.0 / 24389 ? 116 * cbrt(y) - 16 : y * 24389 / 27
    }
}
