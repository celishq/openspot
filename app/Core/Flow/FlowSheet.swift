import Foundation

/// One sheet in the flow of the panel: a spot, and the page of it that shows. A spot's first sheet has no page.
public struct FlowSheet: Equatable, Hashable, Sendable {
    public let spot: String
    /// The ID of the row that opened this page, which each call of the spot gets as `OPENSPOT_PAGE`.
    public let page: String?

    public init(spot: String, page: String? = nil) {
        self.spot = spot
        self.page = page
    }
}
