import Foundation

public struct SettingsFact: Hashable, Sendable {
    public let text: String
    public let symbol: String
    public let isWarning: Bool

    init(_ text: String, _ symbol: String, isWarning: Bool = false) {
        self.text = text
        self.symbol = symbol
        self.isWarning = isWarning
    }
}
