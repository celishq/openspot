import Foundation

/// One sheet in the flow of the panel: a spot, and the page of it that shows, with the title that its edge names. A spot's
/// first sheet has no page. Two sheets are the same when their spot and page are, whatever their titles.
public struct FlowSheet: Hashable, Sendable {
    public let spot: String
    /// The ID of the row that opened this page, which each call of the spot gets as `OPENSPOT_PAGE`.
    public let page: String?
    /// The title of the row or the push that opened it, or nil to take the name of its spot or its page.
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
