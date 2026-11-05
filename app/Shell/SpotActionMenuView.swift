import OpenspotCore
import SwiftUI

/// The actions of the selected row or card, each with its key.
struct SpotActionMenuView: View {
    let menu: ActionMenu
    let onPress: (Int) -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
    }

    var body: some View {
        VStack(spacing: SpotTokens.menuRowGap) {
            ForEach(Array(menu.rows.enumerated()), id: \.offset) { index, row in
                Button {
                    onPress(index)
                } label: {
                    HStack(spacing: SpotTokens.padding) {
                        Text(menu.title(of: row))
                            .font(SpotType.body)
                            .foregroundStyle(titleColor(of: row))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(row.keyLabel)
                            .font(SpotType.detail)
                            .modifier(SpotSecondaryText())
                    }
                    .padding(.horizontal, SpotTokens.padding - SpotTokens.menuPadding + 4)
                    .frame(height: SpotTokens.menuRowHeight)
                    .background(Color.white.opacity(index == menu.selected ? 0.3 : 0), in: shape)
                    .contentShape(shape)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(SpotTokens.menuPadding)
        .frame(width: SpotTokens.gridWidth)
        .modifier(SpotGlass(radius: SpotTokens.radius - SpotTokens.padding + SpotTokens.menuPadding))
    }

    private func titleColor(of row: ActionMenu.Row) -> Color {
        menu.confirming != nil && row.action?.id == menu.confirming
            ? Color(red: 1, green: 0.62, blue: 0.58)
            : .white.opacity(SpotTokens.titleOpacity)
    }
}
