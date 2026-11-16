import OpenspotCore
import SwiftUI

struct SpotSubmenuView: View {
    @Environment(\.spotSurfaceEdge) private var surface
    let model: SpotsModel

    private var shape: SpotRoundShape {
        SpotRoundShape(surface.inner())
    }

    var body: some View {
        let rows = model.menuSession?.menu.submenu?.rows ?? []
        let outline = SpotRoundShape(radius: SpotActionMenuView.radius)
        VStack(spacing: SpotTokens.menuRowGap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                button(row, at: index)
            }
        }
        .padding(SpotTokens.menuPadding)
        .frame(width: ActionMenuFrame.width, alignment: .top)
        .spotGlass(in: outline)
        .environment(\.spotIsShown, true)
    }

    private func button(_ row: ActionMenu.Row, at index: Int) -> some View {
        Button {
            model.pressSubmenu(row: index)
        } label: {
            HStack(spacing: SpotTokens.padding) {
                Text(row.title).font(SpotType.body).lineLimit(1)
                Spacer(minLength: 0)
                Text(row.keyLabel)
                    .font(SpotType.detail)
                    .modifier(SpotSecondaryText())
            }
            .padding(.horizontal, SpotTokens.menuTextInset)
            .frame(height: SpotTokens.menuRowHeight)
            .modifier(SpotLiveSelectionRing(isSelected: { [model] in model.menuSession?.menu.submenu?.selected == index }, shape: shape))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .modifier(SpotPointerMove { model.pointSubmenu(row: index) })
    }
}
