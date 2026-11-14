import OpenspotCore
import SwiftUI

struct SpotActionMenuView: View, @MainActor Equatable {
    let menu: ActionMenu
    let frame: ActionMenuFrame
    var isSettled = true
    var work: (ActionMenu.Row) -> ScriptCall? = { _ in nil }
    let onPress: (Int) -> Void
    var onPoint: (Int) -> Void = { _ in }
    var onSearch: @MainActor @Sendable (String) -> Void = { _ in }
    let selection: () -> Int

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
            ForEach(menu.headers, id: \.line) { header in
                let line = frame.headerRect(header, of: menu)
                Text(header.title)
                    .font(SpotType.detail)
                    .lineLimit(1)
                    .modifier(SpotSecondaryText())
                    .padding(.horizontal, SpotTokens.padding - SpotTokens.menuPadding + 4)
                    .frame(width: line.width, height: line.height, alignment: .bottomLeading)
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
                title(of: row, isRunning: call != nil, isConfirming: isConfirming)
                Spacer(minLength: 0)
                if row.children.isEmpty {
                    Text(row.keyLabel)
                        .font(SpotType.detail)
                        .modifier(SpotSecondaryText())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .modifier(SpotSecondaryText())
                }
            }
            .padding(.horizontal, SpotTokens.padding - SpotTokens.menuPadding + 4)
            .frame(height: SpotTokens.menuRowHeight)
            .spotFill(isActive: call != nil, otherwise: isConfirming ? SpotTheme.confirm : .clear, in: shape)
            .modifier(SpotLiveSelectionRing(isSelected: { [selection] in index == selection() && !isConfirming }, shape: shape))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .modifier(SpotPointerMove { onPoint(index) })
    }

    private var field: some View {
        SpotSteadyField(prompt: "Search actions", text: menu.query, isSettled: isSettled, onSearch: onSearch)
    }

    @ViewBuilder
    private func title(of row: ActionMenu.Row, isRunning: Bool, isConfirming: Bool) -> some View {
        let text = Text(menu.title(of: row, isRunning: isRunning)).font(SpotType.body).lineLimit(1)
        if isConfirming {
            text.foregroundStyle(SpotTheme.onConfirm)
        } else {
            text
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.menu.rows == rhs.menu.rows && lhs.menu.shown == rhs.menu.shown && lhs.menu.query == rhs.menu.query
            && lhs.menu.confirming == rhs.menu.confirming && lhs.frame == rhs.frame && lhs.isSettled == rhs.isSettled
    }
}
