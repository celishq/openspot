import Foundation

/// An item with its texts folded for search, made once so that each search reads them as they are.
struct FoldedItem: Equatable, Sendable {
    let item: SpotItem
    let title: FoldedText
    let subtitle: FoldedText?

    init(_ item: SpotItem) {
        self.item = item
        title = FoldedText(item.title)
        subtitle = item.subtitle.map(FoldedText.init)
    }
}
