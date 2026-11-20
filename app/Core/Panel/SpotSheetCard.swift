import Foundation

public struct SpotSheetCard {
    public let id: String
    public let placement: SpotPlacement
    public let kind: SpotKind
    public let look: SpotsModel.Entry?
    public var state: SpotState?
    public var left: CGFloat = 0

    @MainActor
    public static func of(_ sheetID: String?, in model: SpotsModel) -> SpotSheetCard? {
        guard let sheetID else { return nil }
        let owner = OwnedSheet.owner(of: sheetID)?.spot ?? sheetID
        let visible = model.visible
        let source = sheetID == model.transition.id ? model.transition.source : nil
        let index = visible.firstIndex { $0.id == owner } ?? source.flatMap { source in visible.firstIndex { $0.id == source } }
        guard let index, let placement = model.placements.first(where: { $0.index == index }) else { return nil }
        let entry = visible[index]
        let face = entry.state.face
        let isDrawn = entry.item == nil && (face.layout(for: placement.size) != nil || face.hasView && entry.spot.view != nil)
        return SpotSheetCard(id: entry.id, placement: placement, kind: entry.kind, look: entry.id != owner || isDrawn ? entry : nil, state: entry.id == sheetID ? nil : entry.shownState, left: model.panels.leftExtent)
    }

    public func frame(scrollOffset: CGFloat) -> CGRect {
        let origin = SpotTokens.gridOrigin(scrollOffset: scrollOffset, left: left)
        return placement.rect.offsetBy(dx: origin.x, dy: origin.y)
    }

    public func isSeen(scrollOffset: CGFloat, gridHeight: CGFloat) -> Bool {
        let middle = frame(scrollOffset: scrollOffset).midY
        let bottom = min(gridHeight, SpotTokens.panelHeight) - SpotTokens.halo - SpotTokens.hintBlock
        return middle >= SpotTokens.gridTop && middle <= bottom
    }
}
