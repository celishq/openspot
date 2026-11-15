import Foundation

public struct AccountHandle: Equatable, Sendable {
    public static let rule = "A handle has 3 to 20 of a–z, 0–9, - and _."
    private static let letters = Set("abcdefghijklmnopqrstuvwxyz0123456789-_")
    private static let length = 3...20

    public let text: String

    public init?(_ text: String) {
        guard Self.length.contains(text.count), text.allSatisfy(Self.letters.contains) else { return nil }
        self.text = text
    }

    public static func suggestion(from name: String) -> String {
        String(name.lowercased().filter(letters.contains).prefix(length.upperBound))
    }
}
