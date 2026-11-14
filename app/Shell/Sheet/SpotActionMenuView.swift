import OpenspotCore
import SwiftUI

/// The actions of the selected row or card, each with its key. The panel draws its surface.
struct SpotActionMenuView: View {
    let menu: ActionMenu
    /// Where the menu and each of its lines lie.
    let frame: ActionMenuFrame
    /// Whether the menu has stopped moving, which its field needs.
    var isSettled = true
    var work: (ActionMenu.Row) -> ScriptCall? = { _ in nil }
    let onPress: (Int) -> Void
    /// Takes the row that the pointer moves onto.
    var onPoint: (Int) -> Void = { _ in }
    /// Takes the text of the field of a menu that searches its rows.
    var onSearch: @MainActor @Sendable (String) -> Void = { _ in }

    static let radius = SpotTokens.radius - SpotTokens.padding + SpotTokens.menuPadding

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
    }

    var body: some View {
        let rect = frame.rect(of: menu)
        ZStack(alignment: .topLeading) {
            if let line = frame.fieldRect(of: menu) {
                field
                    .frame(width: line.width)
                    .offset(x: line.minX - rect.minX, y: line.minY - rect.minY)
            }
            ForEach(Array(menu.shown.enumerated()), id: \.offset) { index, row in
                let line = frame.rowRect(index, of: menu)
                button(row, at: index)
                    .frame(width: line.width)
                    .offset(x: line.minX - rect.minX, y: line.minY - rect.minY)
            }
        }
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
    }

    private func button(_ row: ActionMenu.Row, at index: Int) -> some View {
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
            .background(fill(of: row), in: shape)
            .modifier(SpotSelectionRing(isSelected: index == menu.selected && !isConfirming(row), shape: shape))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .modifier(SpotPointerMove { onPoint(index) })
    }

    /// The field that searches the rows.
    private var field: some View {
        SpotSteadyField(prompt: "Search actions", text: menu.query, isSettled: isSettled, onSearch: onSearch)
    }

    private func isConfirming(_ row: ActionMenu.Row) -> Bool {
        work(row) == nil && menu.confirming != nil && row.action?.id == menu.confirming
    }

    private func fill(of row: ActionMenu.Row) -> Color {
        isConfirming(row) ? SpotTheme.confirm : .clear
    }

    private func titleColor(of row: ActionMenu.Row) -> Color {
        isConfirming(row) ? SpotTheme.onConfirm : row.isDestructive ? SpotTheme.confirm : SpotTheme.ink
    }
}
