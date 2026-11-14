import AppKit
import SwiftUI

/// The store: a sidebar with the search and a row for each origin, and beside it each spot as its card at the size it takes
/// on the grid, under the title of its group, in rows that wrap and fade at each end they pass. A plus on a card gets the
/// spot, an up arrow publishes your own spot's changes, and a click shows its readme. A footer holds a hint, the sort and Done.
struct SpotView: View {
    let spot: SpotInput
    @State private var query = ""
    @State private var origin = Origin.all
    @State private var order = Order.name
    @State private var opened: String?
    @State private var edges = Edges()
    @State private var readmeHeight: CGFloat = 0

    /// Where the spots that the sidebar keeps come from.
    private enum Origin: String, CaseIterable, Identifiable {
        case all = "All", core = "Core", mine = "Yours", store = "Shared"

        var id: Self { self }

        /// The word of `openspot store list` for this origin, or nil for all.
        var word: String? {
            switch self {
            case .all: nil
            case .core: "core"
            case .mine: "mine"
            case .store: "store"
            }
        }

        var symbol: String {
            switch self {
            case .all: "square.grid.2x2"
            case .core: "shippingbox"
            case .mine: "person.crop.circle"
            case .store: "person.2"
            }
        }

        /// The tip of its row in the sidebar.
        var tip: String {
            switch self {
            case .all: "Show every spot"
            case .core: "Show the spots that come with Openspot"
            case .mine: "Show the spots you made"
            case .store: "Show the spots shared with you"
            }
        }
    }

    /// How the cards of each group are ordered.
    private enum Order: String, CaseIterable, Identifiable {
        case name = "Name", size = "Size"

        var id: Self { self }
    }

    /// How far the cards have scrolled past each end, from 0 to 1, which sets the strength of the fade at that end.
    private struct Edges: Equatable {
        var top = 0.0
        var bottom = 0.0
    }

    /// One spot of the store: its id, its name, what its button does, its origin, its description, its size, and the folded
    /// words that a search compares, made once.
    private struct Item: Identifiable {
        let id: String
        let name: String
        let state: String
        let origin: String
        let detail: String
        let size: String
        let words: String

        init?(_ line: String) {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 6 else { return nil }
            (id, name, state, origin, detail, size) = (parts[0], parts[1], parts[2], parts[3], parts[4], parts[5])
            words = [name, detail, Self.label(of: origin)].joined(separator: " ").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        }

        /// The cells that its card covers on the grid.
        var area: Int {
            ["small": 1, "wide": 2, "square": 4, "strip": 4, "large": 8][size] ?? 1
        }

        /// The word of the sidebar that names its origin.
        static func label(of origin: String) -> String {
            Origin.allCases.first { $0.word == origin }?.rawValue ?? origin
        }
    }

    private static let sidebarWidth: CGFloat = 200
    private static let fadeLength: CGFloat = 32

    var body: some View {
        let all = spot.all("value").compactMap(Item.init)
        let items = kept(all)
        HStack(spacing: 0) {
            sidebar(all)
            VStack(spacing: 0) {
                ZStack {
                    gallery(items)
                    if items.isEmpty { empty }
                }
                footer
            }
        }
    }

    /// The spots that the search and the origin keep, in the chosen order.
    private func kept(_ all: [Item]) -> [Item] {
        let folded = query.trimmingCharacters(in: .whitespaces).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let kept = all.filter { item in
            (origin.word == nil || item.origin == origin.word) && (folded.isEmpty || item.words.contains(folded))
        }
        switch order {
        case .name: return kept.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size: return kept.sorted { ($0.area, $1.name) > ($1.area, $0.name) }
        }
    }

    /// The search, and under it a row for each origin with its picture and the number of its spots.
    private func sidebar(_ all: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            search
                .padding(.bottom, 10)
            ForEach(Origin.allCases) { each in
                row(each, count: each.word.map { word in all.filter { $0.origin == word }.count } ?? all.count)
            }
            Spacer(minLength: 0)
        }
        .padding(spot.inset)
        .frame(width: Self.sidebarWidth)
    }

    /// A field whose whole fill takes a click, whose Esc clears it, and whose cross clears it too.
    private var search: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(spot.ink.opacity(spot.secondary))
            TextField("Search spots", text: $query)
                .textFieldStyle(.plain)
                .onExitCommand { query = "" }
            if !query.isEmpty {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(spot.ink.opacity(spot.secondary))
                    .contentShape(Circle())
                    .onTapGesture { query = "" }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Clear the search")
                    .help("Clear the search")
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(spot.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .help("Search spots by name, description or origin")
    }

    /// The row of an origin, filled while it is the chosen one.
    private func row(_ each: Origin, count: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return HStack(spacing: 10) {
            Image(systemName: each.symbol)
                .font(.system(size: 14))
                .foregroundStyle(spot.ink.opacity(spot.secondary))
                .frame(width: 20)
            Text(each.rawValue)
                .font(.system(size: 13))
                .foregroundStyle(spot.ink)
            Spacer(minLength: 0)
            Text("\(count)")
                .font(spot.font.detail)
                .foregroundStyle(spot.ink.opacity(spot.secondary))
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
        .background(origin == each ? spot.ink.opacity(0.1) : .clear, in: shape)
        .contentShape(shape)
        .onTapGesture { origin = each }
        .accessibilityAddTraits(origin == each ? [.isButton, .isSelected] : .isButton)
        .help(each.tip)
    }

    /// The groups of cards, which scroll to the edge of the window and fade at each end that has cards past it.
    private func gallery(_ items: [Item]) -> some View {
        let groups = [
            ("Get more spots", items.filter { $0.state == "get" }),
            ("Yours to publish", items.filter { $0.state == "publish" }),
            ("Added", items.filter { $0.state == "added" })
        ].filter { !$0.1.isEmpty }
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(Array(groups.enumerated()), id: \.element.0) { index, group in
                    if index > 0 {
                        Rectangle()
                            .fill(spot.ink.opacity(0.1))
                            .frame(height: 1)
                    }
                    section(groups.count > 1 ? group.0 : nil, group.1)
                }
            }
            .padding(.horizontal, spot.inset)
            .padding(.top, spot.inset)
            .padding(.bottom, Self.fadeLength)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onScrollGeometryChange(for: Edges.self) { geometry in
            let below = geometry.contentSize.height - geometry.containerSize.height - geometry.contentOffset.y
            return Edges(top: min(max(geometry.contentOffset.y / 24, 0), 1), bottom: min(max(below / 24, 0), 1))
        } action: { _, new in
            edges = new
        }
        .mask(fade)
    }

    /// The mask of the cards: clear at each end as far as the cards have scrolled past it.
    private var fade: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(1 - edges.top), .black], startPoint: .top, endPoint: .bottom)
                .frame(height: Self.fadeLength)
            Color.black
            LinearGradient(colors: [.black, .black.opacity(1 - edges.bottom)], startPoint: .top, endPoint: .bottom)
                .frame(height: Self.fadeLength)
        }
    }

    /// What shows when no spot is kept: a picture, why, and the step that brings spots back.
    private var empty: some View {
        let isSearch = !query.trimmingCharacters(in: .whitespaces).isEmpty
        return VStack(spacing: 8) {
            Image(systemName: isSearch ? "magnifyingglass" : origin.symbol)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(spot.ink.opacity(spot.secondary))
                .padding(.bottom, 4)
            Text(isSearch ? "No Spots Match “\(query)”" : "No Spots Here")
                .font(spot.font.title)
                .foregroundStyle(spot.ink)
            Text(isSearch ? "Check the spelling, or try other words." : origin == .all ? "The store has no spots yet." : "Nothing is in \(origin.rawValue) yet.")
                .font(spot.font.detail)
                .foregroundStyle(spot.ink.opacity(spot.secondary))
                .multilineTextAlignment(.center)
            if isSearch {
                Button("Clear Search") { query = "" }
                    .help("Show the spots again")
                    .padding(.top, 6)
            } else if origin != .all {
                Button("Show All Spots") { origin = .all }
                    .help("Show the spots of every origin")
                    .padding(.top, 6)
            }
        }
        .padding(spot.inset * 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The hint of what a card takes, the order of the cards and Done, which closes the store.
    private var footer: some View {
        HStack(spacing: 12) {
            Text("Drag a spot onto your grid to add it.")
                .font(spot.font.detail)
                .foregroundStyle(spot.ink.opacity(spot.secondary))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            Picker("Sort", selection: $order) {
                ForEach(Order.allCases) { Text("By \($0.rawValue)").tag($0) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
            .help("Choose how the cards of each group are ordered")
            Button("Done") { NSApp.keyWindow?.performClose(nil) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .help("Close the store")
        }
        .padding(.horizontal, spot.inset)
        .padding(.vertical, 12)
    }

    /// A group of cards, under its title when the store shows more than one group.
    private func section(_ title: String?, _ list: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title)
                    .font(spot.font.title)
                    .foregroundStyle(spot.ink.opacity(spot.secondary))
            }
            Flow(gap: 16) {
                ForEach(list) { tile($0) }
            }
        }
    }

    /// A card with its corner control, which a click opens to its readme.
    private func tile(_ item: Item) -> some View {
        let size = spot.cardSize(item.id)
        return spot.card(item.id)
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .onTapGesture { open(item) }
            .help("Click to read about \(item.name). Drag it onto your grid to add it.")
            .overlay(alignment: .topLeading) { control(item, card: size) }
            .popover(isPresented: Binding(get: { opened == item.id }, set: { if !$0, opened == item.id { opened = nil } }), arrowEdge: .bottom) {
                about(item)
            }
    }

    /// Opens the readme of a spot, which the store reads for it.
    private func open(_ item: Item) {
        opened = item.id
        spot.send("about:\(item.id)")
    }

    /// The name, the description and the readme of a spot, with its headings in bold.
    private func about(_ item: Item) -> some View {
        let lines = spot["about"] == item.id ? spot.all("readme") : nil
        return VStack(alignment: .leading, spacing: 8) {
            Text(item.name)
                .font(.headline)
            if !item.detail.isEmpty {
                Text(item.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Divider()
            if let lines {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if lines.isEmpty {
                            Text("\(item.name) has no readme yet.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            readme(line)
                        }
                    }
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { readmeHeight = $0 }
                }
                .frame(height: min(max(readmeHeight, 16), 320))
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    /// One line of a readme: a heading in bold, and the rest with its inline marks.
    @ViewBuilder
    private func readme(_ line: String) -> some View {
        if line.hasPrefix("#") {
            Text(line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces))
                .font(.headline)
                .padding(.top, 4)
        } else {
            let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            Text((try? AttributedString(markdown: line, options: options)) ?? AttributedString(line))
        }
    }

    /// The control on the top left rim of a card, as on the cards of Edit Spots: a plus that gets a spot you lack, an up
    /// arrow that publishes your own spot's changes, and none on a spot you have.
    @ViewBuilder
    private func control(_ item: Item, card: CGSize) -> some View {
        switch item.state {
        case "get": corner("plus", label: "Get \(item.name)", card: card) { spot.send("get:\(item.id)") }
        case "publish": corner("arrow.up", label: "Publish the changes of \(item.name)", card: card) { spot.send("publish:\(item.id)") }
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
