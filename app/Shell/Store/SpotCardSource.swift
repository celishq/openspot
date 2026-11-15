import OpenspotCore
import SwiftUI

extension EnvironmentValues {
    @Entry var spotCards = SpotCardSource(model: nil)
}

@MainActor
struct SpotCardSource {
    let model: SpotsModel?

    func view(_ id: String) -> AnyView {
        guard let model, let entry = model.storeEntry(id) else { return AnyView(EmptyView()) }
        let shape = RoundedRectangle(cornerRadius: SpotTokens.corner(for: entry.size), style: .continuous)
        return AnyView(
            SpotCardView(entry: entry, size: entry.size, index: Self.unselectable, isPressed: false, takesDrag: false, isDropTarget: false, chainLetter: nil, model: model)
                .background { SpotBlur(radius: SpotTheme.blur).overlay(SpotTheme.glass).clipShape(shape) }
                .allowsHitTesting(false)
        )
    }

    func sheet(_ id: String) -> AnyView {
        guard let model, let entry = model.storeEntry(id) else { return AnyView(EmptyView()) }
        return AnyView(SpotSampleSheet(model: model, id: id, entry: entry))
    }

    func cornerButton(_ symbol: String, label: String, card id: String, action: @escaping () -> Void) -> AnyView {
        guard let size = model?.storeEntry(id)?.size else { return AnyView(EmptyView()) }
        return AnyView(SpotCornerButton(symbol: symbol, label: label, corner: .leading, size: size, onHover: { _ in }, action: action))
    }

    private static let unselectable = Int.min

    func size(_ id: String) -> CGSize {
        guard let size = model?.storeEntry(id)?.size else { return .zero }
        return CGSize(width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows))
    }
}
