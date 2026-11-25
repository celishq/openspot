import OpenspotCore
import SwiftUI

struct SpotSlotPick: View {
    let model: SpotsModel
    let pick: SlotPick
    @FocusState private var isFocused: Bool

    var body: some View {
        let width = SpotTokens.slotPickWidth
        let height = SpotTokens.storeRowHeight + CGFloat(max(pick.ids.count, 1)) * SpotTokens.listRow + 2 * SpotTokens.slotPickPadding
        let slot = SpotPlacement(index: 0, row: pick.cell.row, column: pick.cell.column, size: .small).rect
        let below = slot.maxY + SpotTokens.rowGap
        let y = below + height <= model.grid.height ? below : max(slot.minY - SpotTokens.rowGap - height, 0)
        let x = min(slot.minX, max(model.grid.width - width, 0))
        VStack(alignment: .leading, spacing: 0) {
            TextField("Search your spots", text: Binding(get: { model.slotPick?.query ?? "" }, set: { model.searchSlotPick($0) }))
                .textFieldStyle(.plain)
                .focused($isFocused)
                .font(SpotType.body)
                .padding(.horizontal, SpotTokens.windowRowPadding)
                .frame(height: SpotTokens.storeRowHeight)
                .background(SpotTheme.ink.opacity(SpotTheme.control), in: SpotRoundShape(radius: SpotTokens.storeRowRadius))
            if pick.ids.isEmpty {
                Text("None of your spots off the grid match.")
                    .font(SpotType.detail)
                    .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
                    .frame(height: SpotTokens.listRow)
            }
            ForEach(Array(pick.ids.enumerated()), id: \.element) { index, id in
                if let entry = model.offGrid.first(where: { $0.id == id }) {
                    HStack(spacing: SpotTokens.wordsGap) {
                        SpotGlyph(entry: entry)
                        Text(entry.spot.name)
                            .font(SpotType.body)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, SpotTokens.windowRowPadding)
                    .frame(height: SpotTokens.listRow)
                    .background(SpotTheme.ink.opacity(index == pick.selected ? SpotTheme.selectedFill : 0), in: SpotRoundShape(radius: SpotTokens.storeRowRadius))
                    .contentShape(Rectangle())
                    .onTapGesture { model.pickSlotSpot(id) }
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
        .foregroundStyle(SpotTheme.ink)
        .padding(SpotTokens.slotPickPadding)
        .frame(width: width, alignment: .topLeading)
        .background(SpotTheme.window, in: SpotRoundShape(radius: SpotTokens.shelfCardRadius))
        .shadow(color: SpotTheme.liftShadowColor.opacity(SpotTheme.liftShadowStrength), radius: SpotTheme.liftShadow, y: SpotTheme.liftShadowDrop)
        .offset(x: x, y: y)
        .onAppear { isFocused = true }
    }
}
