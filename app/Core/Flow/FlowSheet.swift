import Foundation

public struct FlowSheet: Hashable, Sendable {
    public let spot: String
    public let page: String?
    public let title: String?

    public init(spot: String, page: String? = nil, title: String? = nil) {
        self.spot = spot
        self.page = page
        self.title = title
    }

    public static func == (left: FlowSheet, right: FlowSheet) -> Bool {
        left.spot == right.spot && left.page == right.page
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(spot)
        hasher.combine(page)
    }
}
