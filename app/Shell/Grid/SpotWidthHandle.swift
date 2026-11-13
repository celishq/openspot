import AppKit
import OpenspotCore
import SwiftUI

/// The two handles on the side edges of the grid in Edit Spots, which a drag pulls out or in to give the grid 4, 8 or 12
/// columns. A handle follows the pointer, as far as the widest and the narrowest grid, and a release takes the count of
/// columns nearest the width that the pull shows on both sides.
struct SpotWidthHandles: View {
    let model: SpotsModel
    @GestureState private var pull: CGFloat = 0
    @Environment(\.spotPanelWidth) private var panelWidth

    var body: some View {
        if model.isEditing, model.transition.id == nil {
            let width = SpotTokens.width(columns: model.columns)
            let height = min(SpotGrid.height(of: model.placements), SpotTokens.height(rows: 3))
            let top = SpotTokens.gridTop + max(height - Self.box.height, 0) / 2
            let reach = (SpotTokens.width(columns: SpotGrid.columnCounts.last ?? 12) - width) / 2
            let shrink = (width - SpotTokens.width(columns: SpotGrid.columnCounts.first ?? 4)) / 2
            let shown = min(max(pull, -shrink), reach)
            ZStack(alignment: .topLeading) {
                handle(outward: -1, width: width)
                    .offset(x: SpotTokens.halo - Self.box.width - shown, y: top)
                handle(outward: 1, width: width)
                    .offset(x: SpotTokens.halo + width + shown, y: top)
            }
            .frame(width: panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
            .onDisappear { NSCursor.arrow.set() }
        }
    }

    private static let box = CGSize(width: SpotTokens.resizeHandle, height: 72)

    /// One handle: a bold line in the colour of text, in a box that takes the drag. `outward` is the way that grows the grid.
    private func handle(outward: CGFloat, width: CGFloat) -> some View {
        Capsule()
            .fill(SpotTheme.ink)
            .frame(width: SpotTokens.resizeHandleLine, height: Self.box.height / 2)
            .frame(width: Self.box.width, height: Self.box.height)
            .contentShape(Rectangle())
            .onHover { isOver in (isOver ? NSCursor.resizeLeftRight : NSCursor.arrow).set() }
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .updating($pull) { value, pull, _ in pull = outward * value.translation.width }
                    .onEnded { value in
                        NSCursor.arrow.set()
                        model.setColumns(SpotGrid.columns(fitting: width + 2 * outward * value.translation.width))
                    }
            )
            .accessibilityLabel(outward < 0 ? "Left edge of the grid" : "Right edge of the grid")
    }
}
