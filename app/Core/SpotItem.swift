import Foundation

public struct SpotItem: Equatable, Decodable, Sendable {
    public let title: String
    public let run: String

    public init(title: String, run: String) {
        self.title = title
        self.run = run
    }
}
