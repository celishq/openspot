import OpenspotCore
import SwiftUI

/// The actions of the selected row or card, each with its key. The panel draws its surface. It equals another menu of the
/// same rows, so that a move of the selection reruns only the rings, which read it themselves.
struct SpotActionMenuView: View, @MainActor Equatable {
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
    /// Reads the selected row where it is called. Nil reads it from the menu.
    var selection: (() -> Int)?

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
        let call = work(row)
        let isConfirming = call == nil && menu.confirming != nil && row.action?.id == menu.confirming
        return Button {
            onPress(index)
        } label: {
            HStack(spacing: SpotTokens.padding) {
                Text(menu.title(of: row, isRunning: call != nil))
                    .font(SpotType.body)
                    .foregroundStyle(isConfirming ? SpotTheme.onConfirm : SpotTheme.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let call {
                    SpotWorkMark(call: call, side: SpotTokens.workMark)
                }
                Text(row.keyLabel)
                    .font(SpotType.detail)
                    .modifier(SpotSecondaryText())
            }
            .padding(.horizontal, SpotTokens.padding - SpotTokens.menuPadding + 4)
            .frame(height: SpotTokens.menuRowHeight)
            .background(isConfirming ? SpotTheme.confirm : .clear, in: shape)
            .modifier(MenuRing(index: index, selection: selection ?? { [menu] in menu.selected }, isConfirming: isConfirming, shape: shape))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .modifier(SpotPointerMove { onPoint(index) })
    }

    /// The field that searches the rows.
    private var field: some View {
        SpotSteadyField(prompt: "Search actions", text: menu.query, isSettled: isSettled, onSearch: onSearch)
    }

    /// Whether two menus show the same rows. The selection counts only where the menu reads it from its own value.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.menu.rows == rhs.menu.rows && lhs.menu.shown == rhs.menu.shown && lhs.menu.query == rhs.menu.query
            && lhs.menu.confirming == rhs.menu.confirming && lhs.frame == rhs.frame && lhs.isSettled == rhs.isSettled
            && (lhs.selection == nil) == (rhs.selection == nil) && (lhs.selection != nil || lhs.menu.selected == rhs.menu.selected)
    }
}

/// The ring of one row of the menu. It reads the selection itself, so that a move reruns the rings and no row.
private struct MenuRing: ViewModifier {
    let index: Int
    let selection: () -> Int
    let isConfirming: Bool
    let shape: RoundedRectangle

    func body(content: Content) -> some View {
        content.modifier(SpotSelectionRing(isSelected: index == selection() && !isConfirming, shape: shape))
    }
}
