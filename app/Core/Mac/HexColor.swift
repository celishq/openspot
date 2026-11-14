import Foundation

public struct HexColor: Equatable, Sendable {
    public let text: String

    public init(red: Double, green: Double, blue: Double) {
        let parts = [red, green, blue].map { Int((min(max($0, 0), 1) * 255).rounded()) }
        text = "#" + parts.map { String(format: "%02X", $0) }.joined()
    }
}
