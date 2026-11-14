import SwiftUI

/// The store: each spot as its card at the size it takes on the grid, in rows that wrap, under the title of its group, with
/// a plus on the corner of the ones you lack and an up arrow on your own that changed.
struct SpotView: View {
    let spot: SpotInput

    /// One spot of the store: its id, its name and what its button does.
    private struct Item: Identifiable {
        let id: String
        let name: String
        let state: String

        init?(_ line: String) {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 3 else { return nil }
            (id, name, state) = (parts[0], parts[1], parts[2])
        }
    }

    private var items: [Item] {
        spot.all("value").compactMap(Item.init)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                section("Get more spots", items.filter { $0.state == "get" })
                section("Yours to publish", items.filter { $0.state == "publish" })
                section("Added", items.filter { $0.state == "added" })
            }
            .padding(spot.inset * 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ list: [Item]) -> some View {
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(spot.font.title)
                    .foregroundStyle(spot.ink)
                Flow(gap: 16) {
                    ForEach(list) { tile($0) }
                }
            }
        }
    }

    private func tile(_ item: Item) -> some View {
        let size = spot.cardSize(item.id)
        return spot.card(item.id)
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .topLeading) { control(item, card: size) }
    }

    /// The control on the top left rim of a card, as on the cards of Edit Spots: a plus that gets a spot you lack, an up
    /// arrow that publishes your own spot's changes, and none on a spot you have.
    @ViewBuilder
    private func control(_ item: Item, card: CGSize) -> some View {
        switch item.state {
        case "get": corner("plus", label: "Get \(item.name)", card: card) { spot.send("get:\(item.id)") }
        case "publish": corner("arrow.up", label: "Publish \(item.name)", card: card) { spot.send("publish:\(item.id)") }
        default: EmptyView()
        }
    }

    /// A small round control on the rim of a card's top left corner, which a click presses.
    private func corner(_ symbol: String, label: String, card: CGSize, action: @escaping () -> Void) -> some View {
        let radius: CGFloat = card.height <= 64 && card.width < 289 ? card.height / 2 : 26
        let inset = radius * (1 - 0.5.squareRoot()) - 10
        return Image(systemName: symbol)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(spot.ink)
            .frame(width: 20, height: 20)
            .background(Circle().fill(.background))
            .overlay(Circle().strokeBorder(spot.ink.opacity(0.15)))
            .contentShape(Circle())
            .onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(label)
            .help(label)
            .offset(x: inset, y: inset)
    }
}

/// Lays its views in rows that wrap at the width it gets, each row as tall as its tallest view.
private struct Flow: Layout {
    let gap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let places = place(subviews, in: width)
        return CGSize(width: proposal.width ?? places.map(\.maxX).max() ?? 0, height: places.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (view, rect) in zip(subviews, place(subviews, in: bounds.width)) {
            view.place(at: CGPoint(x: bounds.minX + rect.minX, y: bounds.minY + rect.minY), proposal: ProposedViewSize(rect.size))
        }
    }

    private func place(_ subviews: Subviews, in width: CGFloat) -> [CGRect] {
        var rects: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += line + gap
                line = 0
            }
            rects.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + gap
            line = max(line, size.height)
        }
        return rects
    }
}
