import OpenspotCore
import SwiftUI

/// The actions of the selected row or card, each with its key.
struct SpotActionMenuView: View {
    let menu: ActionMenu
    var work: (ActionMenu.Row) -> ScriptCall? = { _ in nil }
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
                        Text(menu.title(of: row, isRunning: work(row) != nil))
                            .font(SpotType.body)
                            .foregroundStyle(titleColor(of: row))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if let call = work(row) {
                            SpotWorkMark(call: call, side: SpotTokens.workMark)
                        }
                        Text(row.keyLabel)
                            .font(SpotType.detail)
                            .modifier(SpotSecondaryText())
                    }
                    .padding(.horizontal, SpotTokens.padding - SpotTokens.menuPadding + 4)
                    .frame(height: SpotTokens.menuRowHeight)
                    .background(fill(of: row, at: index), in: shape)
                    .contentShape(shape)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(SpotTokens.menuPadding)
        .frame(width: SpotTokens.gridWidth)
        .modifier(SpotGlass(radius: SpotTokens.radius - SpotTokens.padding + SpotTokens.menuPadding, shade: SpotTheme.menuGlass))
    }

    private func isConfirming(_ row: ActionMenu.Row) -> Bool {
        work(row) == nil && menu.confirming != nil && row.action?.id == menu.confirming
    }

    private func fill(of row: ActionMenu.Row, at index: Int) -> Color {
        if isConfirming(row) { return SpotTheme.confirm }
        return SpotTheme.ink.opacity(index == menu.selected ? SpotTheme.menuSelected : 0)
    }

    private func titleColor(of row: ActionMenu.Row) -> Color {
        isConfirming(row) ? SpotTheme.onConfirm : SpotTheme.ink.opacity(SpotTheme.titleOpacity)
    }
}
