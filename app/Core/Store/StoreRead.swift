import Foundation

struct StoreRead: Sendable {
    let sources: [StoreSource]
    let missing: Set<String>
    let cards: [StorePlace: [StoreCard]]
    let tookUpdates: Bool
}
