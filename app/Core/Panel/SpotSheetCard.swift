import Foundation

public struct SpotSheetCard {
    public let id: String
    public let placement: SpotPlacement
    public let look: SpotsModel.Entry?
    public var left: CGFloat = 0

    @MainActor
    public static func of(_ sheetID: String?, in model: SpotsModel) -> SpotSheetCard? {
        guard let sheetID else { return nil }
        let visible = model.visible
        let index = visible.firstIndex { $0.id == sheetID }
            ?? visible.firstIndex { $0.kind == .widget && $0.spot.opens == sheetID }
        guard let index, let placement = model.placements.first(where: { $0.index == index }) else { return nil }
        let entry = visible[index]
        let face = entry.state.face
        let isDrawn = entry.item == nil && (face.layout(for: placement.size) != nil || face.hasView && entry.spot.view != nil)
        return SpotSheetCard(id: entry.id, placement: placement, look: entry.id != sheetID || isDrawn ? entry : nil, left: model.panels.leftExtent)
    }

    public func frame(scrollOffset: CGFloat) -> CGRect {
        let origin = SpotTokens.gridOrigin(scrollOffset: scrollOffset, left: left)
        return placement.rect.offsetBy(dx: origin.x, dy: origin.y)
    }
}
