import SwiftUI

/// The store: each spot as its card at the size it takes on the grid, in rows that wrap, with Get under the ones you lack,
/// Publish under your own that changed, and Added under the rest.
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
        return VStack(alignment: .leading, spacing: 8) {
            spot.card(item.id)
                .frame(width: size.width, height: size.height)
            button(item)
        }
    }

    @ViewBuilder
    private func button(_ item: Item) -> some View {
        switch item.state {
        case "get": pill("Get") { spot.send("get:\(item.id)") }
        case "publish": pill("Publish") { spot.send("publish:\(item.id)") }
        default:
            Text("Added")
                .font(spot.font.detail)
                .foregroundStyle(spot.ink.opacity(spot.secondary))
                .frame(height: 24)
        }
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(spot.accent)
                .padding(.horizontal, 14)
                .frame(height: 24)
                .background(spot.ink.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
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
