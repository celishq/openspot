import OpenspotCore
import SwiftUI

struct SpotSubmenuView: View {
    let model: SpotsModel

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
    }

    var body: some View {
        let rows = model.menuSession?.menu.submenu?.rows ?? []
        let outline = RoundedRectangle(cornerRadius: SpotActionMenuView.radius, style: .continuous)
        VStack(spacing: SpotTokens.menuRowGap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                button(row, at: index)
            }
        }
        .padding(SpotTokens.menuPadding)
        .frame(width: ActionMenuFrame.width, alignment: .top)
        .background {
            SpotBlur(radius: SpotTheme.blur)
                .overlay(SpotTheme.glass)
                .clipShape(outline)
        }
        .overlay(SpotRim(radius: SpotActionMenuView.radius))
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
            .padding(.horizontal, SpotTokens.padding - SpotTokens.menuPadding + 4)
            .frame(height: SpotTokens.menuRowHeight)
            .modifier(SpotLiveSelectionRing(isSelected: { [model] in model.menuSession?.menu.submenu?.selected == index }, shape: shape))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .modifier(SpotPointerMove { model.pointSubmenu(row: index) })
    }
}
