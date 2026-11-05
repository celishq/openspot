import Foundation

/// A colour as a person copies it, such as #1A2B3C, from parts between 0 and 1.
public struct HexColor: Equatable, Sendable {
    public let text: String

    public init(red: Double, green: Double, blue: Double) {
        let parts = [red, green, blue].map { Int((min(max($0, 0), 1) * 255).rounded()) }
        text = "#" + parts.map { String(format: "%02X", $0) }.joined()
    }
}
