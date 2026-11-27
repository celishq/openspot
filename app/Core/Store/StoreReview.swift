import Foundation

public struct StoreReview: Equatable, Sendable {
    public let name: String
    public let from: String
    public let updated: String?
    public let lines: [ReviewLine]
    public let clash: SpotClash?
    let install: SpotInstall
    let clashes: Bool

    func choosing(_ clash: SpotClash) -> StoreReview {
        StoreReview(name: name, from: from, updated: updated, lines: lines, clash: clash, install: install, clashes: clashes)
    }
}
