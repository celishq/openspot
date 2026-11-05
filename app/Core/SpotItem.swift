import Foundation

/// One thing a list offers. Its `run` value goes back to the command when it is picked.
public struct SpotItem: Equatable, Decodable, Sendable {
    public let title: String
    public let subtitle: String?
    public let run: String
    public let symbol: String?
    public let file: String?

    public init(title: String, subtitle: String? = nil, run: String, symbol: String? = nil, file: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.run = run
        self.symbol = symbol
        self.file = file
    }
}
