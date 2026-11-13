import AppKit
import OpenspotCore
import SwiftUI

/// The two handles on the side edges of the grid in Edit Spots, which a drag pulls out or in to give the grid 4, 8 or 12
/// columns. Both sides move together, so the grid grows about its middle. A handle follows the pointer, and a release takes
/// the count of columns nearest the width it shows.
struct SpotWidthHandles: View {
    let model: SpotsModel
    @GestureState private var pull: CGFloat = 0
    @Environment(\.spotPanelWidth) private var panelWidth

    var body: some View {
        let width = SpotTokens.width(columns: model.columns)
        let height = min(SpotGrid.height(of: model.placements), SpotTokens.height(rows: 3))
        let top = SpotTokens.gridTop + max(height - Self.box.height, 0) / 2
        ZStack(alignment: .topLeading) {
            handle(outward: -1)
                .offset(x: SpotTokens.halo - Self.box.width - pull, y: top)
            handle(outward: 1)
                .offset(x: SpotTokens.halo + width + pull, y: top)
        }
        .frame(width: panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
    }

    private static let box = CGSize(width: SpotTokens.resizeHandle, height: 72)

    /// One handle: a bold line in the colour of text, in a box that takes the drag. `outward` is the way that grows the grid.
    private func handle(outward: CGFloat) -> some View {
        Capsule()
            .fill(SpotTheme.ink)
            .frame(width: SpotTokens.resizeHandleLine, height: Self.box.height / 2)
            .frame(width: Self.box.width, height: Self.box.height)
            .contentShape(Rectangle())
            .onHover { isOver in (isOver ? NSCursor.resizeLeftRight : NSCursor.arrow).set() }
            .gesture(
                DragGesture()
                    .updating($pull) { value, pull, _ in pull = outward * value.translation.width }
                    .onEnded { value in
                        let grown = SpotTokens.width(columns: model.columns) + 2 * outward * value.translation.width
                        model.setColumns(SpotGrid.columns(fitting: grown))
                    }
            )
            .accessibilityLabel(outward < 0 ? "Left edge of the grid" : "Right edge of the grid")
    }
}
