import Foundation

public struct SearchText: Equatable, Sendable {
    public let title: String
    public let subtitle: String?
    public let keywords: [String]
    public let glyph: String?

    public init(title: String, subtitle: String? = nil, keywords: [String] = [], glyph: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.keywords = keywords
        self.glyph = glyph
    }
}
