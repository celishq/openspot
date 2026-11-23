import Foundation

public struct FlowSheet: Hashable, Sendable {
    public let spot: String
    public let route: String?
    public let title: String?
    public let source: String?

    public init(spot: String, route: String? = nil, title: String? = nil, source: String? = nil) {
        self.spot = spot
        self.route = route
        self.title = title
        self.source = source
    }

    public static func == (left: FlowSheet, right: FlowSheet) -> Bool {
        left.spot == right.spot && left.route == right.route
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(spot)
        hasher.combine(route)
    }
}
