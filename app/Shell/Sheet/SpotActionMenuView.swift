import OpenspotCore
import SwiftUI

/// The actions of the selected row or card, each with its key.
struct SpotActionMenuView: View {
    let menu: ActionMenu
    /// Whether the field is the last line, as in a menu that grows up from its item, whose bottom stays still.
    var fieldIsLast = false
    var work: (ActionMenu.Row) -> ScriptCall? = { _ in nil }
    let onPress: (Int) -> Void
    /// Takes the text of the field of a menu that searches its rows.
    var onSearch: (String) -> Void = { _ in }
    @FocusState private var isSearching: Bool

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
    }

    var body: some View {
        VStack(spacing: SpotTokens.menuRowGap) {
            if menu.isSearchable, !fieldIsLast {
                field
            }
            ForEach(Array(menu.shown.enumerated()), id: \.offset) { index, row in
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
            }
            if menu.isSearchable, fieldIsLast {
                field
            }
        }
        .padding(SpotTokens.menuPadding)
        .frame(width: ActionMenuPlace.width)
        .modifier(SpotGlass(radius: SpotTokens.radius - SpotTokens.padding + SpotTokens.menuPadding))
    }

    /// The field that searches the rows, at the edge of the menu that stays still while the rows change.
    private var field: some View {
        SpotSearchField(prompt: "Search actions", text: menu.query, onSearch: onSearch, isFocused: $isSearching)
            .onAppear {
                DispatchQueue.main.async { isSearching = true }
            }
    }

    private func isConfirming(_ row: ActionMenu.Row) -> Bool {
        work(row) == nil && menu.confirming != nil && row.action?.id == menu.confirming
    }

    private func fill(of row: ActionMenu.Row) -> Color {
        isConfirming(row) ? SpotTheme.confirm : .clear
    }

    private func titleColor(of row: ActionMenu.Row) -> Color {
        isConfirming(row) ? SpotTheme.onConfirm : SpotTheme.ink
    }
}
