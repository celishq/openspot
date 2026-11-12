import OpenspotCore
import SwiftUI

/// The actions of the selected row or card, each with its key. The panel draws its surface.
struct SpotActionMenuView: View {
    let menu: ActionMenu
    /// Whether the field is the last line, as in a menu that grows up from its item, whose bottom stays still.
    var fieldIsLast = false
    /// Whether the menu has stopped moving. Until then its field is a drawn copy, since a text field of AppKit lies at its
    /// layout place and does not follow the menu's scale, and draws its words lower without the focus. The swap never fades.
    var isSettled = true
    var work: (ActionMenu.Row) -> ScriptCall? = { _ in nil }
    let onPress: (Int) -> Void
    /// Takes the row that the pointer moves onto.
    var onPoint: (Int) -> Void = { _ in }
    /// Takes the text of the field of a menu that searches its rows.
    var onSearch: (String) -> Void = { _ in }
    @FocusState private var isSearching: Bool

    static let radius = SpotTokens.radius - SpotTokens.padding + SpotTokens.menuPadding

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
                .modifier(SpotPointerMove { onPoint(index) })
            }
            if menu.isSearchable, fieldIsLast {
                field
            }
        }
        .padding(SpotTokens.menuPadding)
        .frame(width: ActionMenuPlace.width)
    }

    /// The field that searches the rows, at the edge of the menu that stays still while the rows change.
    private var field: some View {
        ZStack {
            SpotSearchField(prompt: Self.prompt, text: menu.query, onSearch: onSearch, isFocused: $isSearching)
                .animation(nil) { $0.opacity(isSettled ? 1 : 0.001) }
            fieldCopy
                .animation(nil) { $0.opacity(isSettled ? 0 : 1) }
        }
        .onAppear {
            DispatchQueue.main.async { isSearching = true }
        }
    }

    private static let prompt = "Search actions"
    /// How far a text field of AppKit draws its words above a SwiftUI text in the same frame.
    private static let textFieldRise: CGFloat = 1

    /// The field's words and fill, drawn by SwiftUI, which scale with the menu as it moves.
    private var fieldCopy: some View {
        Text(menu.query.isEmpty ? Self.prompt : menu.query)
            .font(SpotType.body)
            .foregroundStyle(menu.query.isEmpty ? SpotTheme.ink.opacity(SpotTheme.secondaryLight) : SpotTheme.ink)
            .lineLimit(1)
            .offset(y: -Self.textFieldRise)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SpotTokens.padding - SpotTokens.menuPadding + 4)
            .frame(height: SpotTokens.menuRowHeight)
            .background(SpotTheme.ink.opacity(SpotTheme.fill), in: RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous))
            .allowsHitTesting(false)
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
