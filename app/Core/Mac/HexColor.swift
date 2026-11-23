import Foundation

public struct HexColor: Equatable, Sendable {
    public let text: String
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        let parts = [red, green, blue, alpha].map { Int((min(max($0, 0), 1) * 255).rounded()) }
        text = "#" + parts.prefix(alpha == 1 ? 3 : 4).map { String(format: "%02X", $0) }.joined()
        (self.red, self.green, self.blue, self.alpha) = (Double(parts[0]) / 255, Double(parts[1]) / 255, Double(parts[2]) / 255, Double(parts[3]) / 255)
    }

    public init?(text: String) {
        let digits = text.dropFirst()
        guard text.first == "#", [6, 8].contains(digits.count), let value = UInt32(digits, radix: 16) else { return nil }
        let full = digits.count == 6 ? value << 8 | 0xFF : value
        let part = { (shift: UInt32) in Double(full >> shift & 0xFF) / 255 }
        self.init(red: part(24), green: part(16), blue: part(8), alpha: part(0))
    }
}
