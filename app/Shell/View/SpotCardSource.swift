import OpenspotCore
import SwiftUI
import UniformTypeIdentifiers

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
                .contentShape(.dragPreview, shape)
                .contentShape(shape)
                .onDrag {
                    model.beginStoreDrag()
                    return Self.dragItem(of: id)
                }
        )
    }

    static func dragItem(of id: String) -> NSItemProvider {
        let item = NSItemProvider()
        item.registerDataRepresentation(forTypeIdentifier: UTType.storeCard.identifier, visibility: .all) { done in
            done(Data(id.utf8), nil)
            return nil
        }
        return item
    }

    static func storeID(on pasteboard: NSPasteboard) -> String? {
        pasteboard.data(forType: NSPasteboard.PasteboardType(UTType.storeCard.identifier)).map { String(decoding: $0, as: UTF8.self) }
    }

    private static let unselectable = Int.min

    func size(_ id: String) -> CGSize {
        guard let size = model?.storeEntry(id)?.size else { return .zero }
        return CGSize(width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows))
    }
}

extension UTType {
    static let storeCard = UTType(exportedAs: "dev.openspot.store-card")
}
