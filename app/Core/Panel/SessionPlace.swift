import Foundation

public struct SessionPlace: Codable, Equatable, Sendable {
    public var flow: Flow
    public var query: String

    var start: FlowSheet? {
        flow.pages.first
    }

    func merges(with other: SessionPlace) -> Bool {
        start == other.start && query == other.query
    }
}
