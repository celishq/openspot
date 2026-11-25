import OpenspotCore
import SwiftUI

struct SpotSlotPick: View {
    @Environment(\.spotSurfaceEdge) private var surface
    let model: SpotsModel
    let pick: SlotPick

    private static var step: CGFloat { SpotTokens.menuRow + SpotTokens.menuRowGap }

    var body: some View {
        let lines = 1 + max(pick.ids.count, 1)
        let slot = SpotPlacement(index: 0, row: pick.cell.row, column: pick.cell.column, size: .small).rect
        let frame = ActionMenuFrame(item: slot, height: SpotTokens.menuHeight(rows: lines), bounds: CGRect(x: 0, y: 0, width: model.grid.width, height: model.grid.height))
        let rect = frame.rect
        let fieldLine = frame.stillEdge == .top ? 0 : lines - 1
        let firstRow = frame.stillEdge == .top ? 1 : 0
        let corner = UnitPoint(x: frame.side == .left ? 0 : 1, y: frame.stillEdge == .top ? 0 : 1)
        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: rect.width, height: rect.height)
                .spotGlass(in: SpotRoundShape(radius: SpotActionMenuView.radius))
                .allowsHitTesting(false)
            SpotSteadyField(prompt: "Search your spots", text: pick.query, isSettled: true, onSearch: { model.searchSlotPick($0) })
                .frame(width: Self.width)
                .offset(x: SpotTokens.menuPadding, y: Self.top(of: fieldLine))
            if pick.ids.isEmpty {
                Text("None of your spots off the grid match.")
                    .font(SpotType.detail)
                    .modifier(SpotSecondaryText())
                    .padding(.horizontal, SpotTokens.menuTextInset)
                    .frame(width: Self.width, height: SpotTokens.menuRow, alignment: .leading)
                    .offset(x: SpotTokens.menuPadding, y: Self.top(of: firstRow))
            }
            ForEach(Array(pick.ids.enumerated()), id: \.element) { index, id in
                if let entry = model.offGrid.first(where: { $0.id == id }) {
                    row(entry, isSelected: index == pick.selected)
                        .offset(x: SpotTokens.menuPadding, y: Self.top(of: firstRow + index))
                }
            }
        }
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
        .transition(.scale(scale: MotionTokens.menuStartScale, anchor: corner).combined(with: .opacity))
        .offset(x: rect.minX, y: rect.minY)
    }

    private static var width: CGFloat {
        SpotTokens.menuWidth - 2 * SpotTokens.menuPadding
    }

    private static func top(of line: Int) -> CGFloat {
        SpotTokens.menuPadding + CGFloat(line) * step
    }

    private func row(_ entry: SpotsModel.Entry, isSelected: Bool) -> some View {
        let shape = SpotRoundShape(surface.inner())
        return Button {
            model.pickSlotSpot(entry.id)
        } label: {
            HStack(spacing: SpotTokens.wordsGap) {
                SpotGlyph(entry: entry)
                Text(entry.spot.name)
                    .font(SpotType.body)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, SpotTokens.menuTextInset)
            .frame(width: Self.width, height: SpotTokens.menuRow)
            .modifier(SpotSelectionRing(isSelected: isSelected, shape: shape))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }
}
