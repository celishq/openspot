import OpenspotCore
import SwiftUI

extension EnvironmentValues {
    /// The cards that a spot's view can draw by `spot.card(id)`.
    @Entry var spotCards = SpotCardSource(model: nil)
}

/// The cards of other spots that a spot's view draws, such as the store's gallery: each at the size the grid gives it, on
/// its glass. A spot that the panel lacks draws its header's face (protocol: Views). A drag of a card carries its store ID
/// and opens Edit Spots, where a drop adds the spot.
@MainActor
struct SpotCardSource {
    let model: SpotsModel?

    /// The card of the spot with this store ID, or nothing when no spot has it.
    func view(_ id: String) -> AnyView {
        guard let model, let entry = model.storeEntry(id) else { return AnyView(EmptyView()) }
        let shape = RoundedRectangle(cornerRadius: SpotTokens.corner(for: entry.size), style: .continuous)
        return AnyView(
            SpotCardView(entry: entry, size: entry.size, index: Self.unselectable, isPressed: false, takesDrag: false, isDropTarget: false, chainLetter: nil, model: model)
                .background { SpotBlur(radius: SpotTheme.blur).overlay(SpotTheme.glass).clipShape(shape) }
                .allowsHitTesting(false)
                .contentShape(.dragPreview, shape)
                .contentShape(shape)
                .onDrag {
                    model.beginStoreDrag()
                    return NSItemProvider(object: Self.dragText(of: id) as NSString)
                }
        )
    }

    /// The text that a drag of a store card carries, and the store ID that a drop reads back from it.
    static func dragText(of id: String) -> String {
        dragPrefix + id
    }

    static func storeID(in text: String?) -> String? {
        guard let text, text.hasPrefix(dragPrefix) else { return nil }
        return String(text.dropFirst(dragPrefix.count))
    }

    private static let dragPrefix = "openspot-store:"

    /// The place in the grid that a store card stands for: none that a selection reaches, so it never shows a ring.
    private static let unselectable = Int.min

    /// The size of the card of the spot with this store ID on the grid.
    func size(_ id: String) -> CGSize {
        guard let size = model?.storeEntry(id)?.size else { return .zero }
        return CGSize(width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows))
    }
}
