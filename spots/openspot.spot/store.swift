import AppKit
import SwiftUI

/// The store, laid out on 16 columns of the grid: a sidebar of 4 with the search and a row for each origin, and 12 with each
/// spot as its card at the size it takes on the grid, under the title of its group. A plus on a card gets the spot, an up
/// arrow publishes your own spot's changes, and a click opens its page with its readme and, when it has sample data, its
/// sheet to try. A footer holds a hint, the sort and Done.
struct SpotView: View {
    let spot: SpotInput
    @State private var query = ""
    @State private var origin = Origin.all
    @State private var order = Order.name
    @State private var opened: String?
    @State private var isTrying = false
    @State private var hovered: String?
    @State private var tip: String?

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

    /// The anchor of the control whose tip shows.
    private struct TipAnchor: PreferenceKey {
        static let defaultValue: Anchor<CGRect>? = nil

        static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
            value = value ?? nextValue()
        }
    }

    /// One spot of the store: its id, its name, what its button does, its origin, its description, its size, whether it
    /// has sample data, and the folded words that a search compares, made once.
    private struct Item: Identifiable {
        let id: String
        let name: String
        let state: String
        let origin: String
        let detail: String
        let size: String
        let hasSample: Bool
        let words: String

        init?(_ line: String) {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 7 else { return nil }
            (id, name, state, origin, detail, size) = (parts[0], parts[1], parts[2], parts[3], parts[4], parts[5])
            hasSample = parts[6] == "sample"
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

    private static let columnGap: CGFloat = 11
    private static let rowGap: CGFloat = 12
    private static let columns: CGFloat = 16
    private static let sidebarColumns: CGFloat = 4

    /// The width of the sidebar: 4 of the 16 columns that fill the window.
    private var sidebarWidth: CGFloat {
        let column = (spot.size.width - 2 * spot.inset - (Self.columns - 1) * Self.columnGap) / Self.columns
        return max(Self.sidebarColumns * column + (Self.sidebarColumns - 1) * Self.columnGap, 180)
    }

    var body: some View {
        let all = spot.all("value").compactMap(Item.init)
        let items = kept(all)
        HStack(spacing: 0) {
            sidebar(all)
            VStack(spacing: 0) {
                if let opened, let item = all.first(where: { $0.id == opened }) {
                    page(item)
                } else {
                    ZStack {
                        gallery(items)
                        if items.isEmpty { empty }
                    }
                }
                footer
            }
        }
        .overlayPreferenceValue(TipAnchor.self) { anchor in
            GeometryReader { proxy in
                if let anchor, let tip {
                    let rect = proxy[anchor]
                    let below = rect.maxY + 15 < proxy.size.height - 15
                    spot.tip(tip)
                        .position(x: min(max(rect.midX, 120), proxy.size.width - 120), y: below ? rect.maxY + 15 : rect.minY - 15)
                }
            }
            .allowsHitTesting(false)
        }
        .task(id: hovered) {
            tip = nil
            guard let hovered else { return }
            try? await Task.sleep(for: .milliseconds(500))
            if !Task.isCancelled { tip = hovered }
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

    /// Shows the tip of a control while the pointer rests on it.
    private func tipped(_ text: String, _ view: some View) -> some View {
        view
            .onHover { inside in
                if inside {
                    hovered = text
                } else if hovered == text {
                    hovered = nil
                }
            }
            .anchorPreference(key: TipAnchor.self, value: .bounds) { tip == text ? $0 : nil }
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
        .padding([.leading, .top, .bottom], spot.inset)
        .frame(width: sidebarWidth + spot.inset)
    }

    /// A field whose whole fill takes a click, whose Esc clears it, and whose cross clears it too.
    private var search: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(spot.ink.opacity(spot.secondary))
            TextField("Search spots", text: $query)
                .textFieldStyle(.plain)
                .onExitCommand { query = "" }
                .onChange(of: query) { opened = nil }
            if !query.isEmpty {
                tipped("Clear the search", Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(spot.ink.opacity(spot.secondary))
                    .contentShape(Circle())
                    .onTapGesture { query = "" }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Clear the search"))
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(spot.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// The row of an origin, filled while it is the chosen one.
    private func row(_ each: Origin, count: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return tipped(each.tip, HStack(spacing: 10) {
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
        .background(origin == each && opened == nil ? spot.ink.opacity(0.1) : .clear, in: shape)
        .contentShape(shape)
        .onTapGesture {
            origin = each
            opened = nil
        }
        .accessibilityAddTraits(origin == each ? [.isButton, .isSelected] : .isButton))
    }

    /// The groups of cards, which scroll to the edges of the window and are cut there.
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
            .padding(.leading, Self.columnGap)
            .padding([.trailing, .top, .bottom], spot.inset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, _ in
            hovered = nil
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
                    .padding(.top, 6)
            } else if origin != .all {
                Button("Show All Spots") { origin = .all }
                    .padding(.top, 6)
            }
        }
        .padding(spot.inset * 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The hint of what a card does, the order of the cards and Done, which closes the store.
    private var footer: some View {
        HStack(spacing: 12) {
            Text("Click a spot to read about it and try it. The plus adds it to your grid.")
                .font(spot.font.detail)
                .foregroundStyle(spot.ink.opacity(spot.secondary))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            if opened == nil {
                tipped("Order the cards of each group", Picker("Sort", selection: $order) {
                    ForEach(Order.allCases) { Text("By \($0.rawValue)").tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize())
            }
            tipped("Close the store", Button("Done") { NSApp.keyWindow?.performClose(nil) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large))
        }
        .padding(.leading, Self.columnGap)
        .padding([.trailing, .bottom], spot.inset)
        .padding(.top, 8)
    }

    /// A group of cards, under its title when the store shows more than one group.
    private func section(_ title: String?, _ list: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title)
                    .font(spot.font.title)
                    .foregroundStyle(spot.ink.opacity(spot.secondary))
            }
            Flow(gap: Self.columnGap, line: Self.rowGap) {
                ForEach(list) { tile($0) }
            }
        }
    }

    /// A card with its corner control, which a click opens to its page.
    private func tile(_ item: Item) -> some View {
        let size = spot.cardSize(item.id)
        return tipped("Read about \(item.name)", spot.card(item.id)
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .onTapGesture { open(item) })
            .overlay(alignment: .topLeading) { control(item, card: size) }
    }

    /// Opens the page of a spot, and asks the store for its readme.
    private func open(_ item: Item) {
        hovered = nil
        isTrying = false
        opened = item.id
        spot.send("about:\(item.id)")
    }

    /// The page of a spot: its card, name and description beside what its button does, then its readme, or its sheet with
    /// sample data while the person tries it.
    private func page(_ item: Item) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                tipped("Back to all spots", HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("All Spots")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(spot.accent)
                .contentShape(Rectangle())
                .onTapGesture { opened = nil }
                .accessibilityAddTraits(.isButton))
                HStack(alignment: .center, spacing: 16) {
                    let size = spot.cardSize(item.id)
                    spot.card(item.id)
                        .frame(width: size.width, height: size.height)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(spot.ink)
                        if !item.detail.isEmpty {
                            Text(item.detail)
                                .font(.system(size: 13))
                                .foregroundStyle(spot.ink.opacity(spot.secondary))
                        }
                        Text(Item.label(of: item.origin))
                            .font(spot.font.detail)
                            .foregroundStyle(spot.ink.opacity(spot.secondary))
                    }
                    Spacer(minLength: 0)
                    step(item)
                }
                if item.hasSample {
                    tipped(isTrying ? "Show what the spot does" : "Use \(item.name) with sample data. Nothing you do here runs.", Button {
                        isTrying.toggle()
                    } label: {
                        Label(isTrying ? "Back to Readme" : "Try Without Installing", systemImage: isTrying ? "doc.text" : "play.fill")
                    }
                    .controlSize(.large))
                }
                if isTrying {
                    VStack(spacing: 10) {
                        spot.sheet(item.id)
                        Text("Sample data. Clicks here run nothing and change nothing on your Mac.")
                            .font(spot.font.detail)
                            .foregroundStyle(spot.ink.opacity(spot.secondary))
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    readme(item)
                }
            }
            .padding(.leading, Self.columnGap)
            .padding([.trailing, .top, .bottom], spot.inset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, _ in
            hovered = nil
        }
    }

    /// What the button of a spot's page does: get it, publish your changes, or nothing once you have it.
    @ViewBuilder
    private func step(_ item: Item) -> some View {
        switch item.state {
        case "get":
            tipped("Add \(item.name) to your grid", Button("Get") { spot.send("get:\(item.id)") }
                .buttonStyle(.borderedProminent)
                .controlSize(.large))
        case "publish":
            tipped("Publish the changes of \(item.name)", Button("Publish") { spot.send("publish:\(item.id)") }
                .controlSize(.large))
        default:
            Label("Added", systemImage: "checkmark")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(spot.ink.opacity(spot.secondary))
        }
    }

    /// The readme of a spot, with its headings in bold, or a line that says it has none.
    @ViewBuilder
    private func readme(_ item: Item) -> some View {
        if spot["about"] == item.id {
            let lines = spot.all("readme")
            VStack(alignment: .leading, spacing: 6) {
                if lines.isEmpty {
                    Text("\(item.name) has no readme yet.")
                        .foregroundStyle(spot.ink.opacity(spot.secondary))
                }
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    if line.hasPrefix("#") {
                        Text(line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(spot.ink)
                            .padding(.top, 6)
                    } else {
                        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                        Text((try? AttributedString(markdown: line, options: options)) ?? AttributedString(line))
                            .foregroundStyle(spot.ink)
                    }
                }
            }
            .font(.system(size: 13))
            .textSelection(.enabled)
            .frame(maxWidth: 560, alignment: .leading)
        } else {
            ProgressView()
                .controlSize(.small)
        }
    }

    /// The control on the top left rim of a card, as on the cards of Edit Spots: a plus that gets a spot you lack, an up
    /// arrow that publishes your own spot's changes, and none on a spot you have.
    @ViewBuilder
    private func control(_ item: Item, card: CGSize) -> some View {
        switch item.state {
        case "get": corner("plus", label: "Add \(item.name) to your grid", card: card) { spot.send("get:\(item.id)") }
        case "publish": corner("arrow.up", label: "Publish the changes of \(item.name)", card: card) { spot.send("publish:\(item.id)") }
        default: EmptyView()
        }
    }

    /// A small round control on the rim of a card's top left corner, which a click presses.
    private func corner(_ symbol: String, label: String, card: CGSize, action: @escaping () -> Void) -> some View {
        let radius: CGFloat = card.height <= 64 && card.width < 289 ? card.height / 2 : 26
        let inset = radius * (1 - 0.5.squareRoot()) - 10
        return tipped(label, Image(systemName: symbol)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(spot.ink)
            .frame(width: 20, height: 20)
            .background(Circle().fill(.background))
            .overlay(Circle().strokeBorder(spot.ink.opacity(0.15)))
            .contentShape(Circle())
            .onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(label))
            .offset(x: inset, y: inset)
    }
}

/// Lays its views in rows that wrap at the width it gets, each row as tall as its tallest view.
private struct Flow: Layout {
    let gap: CGFloat
    let line: CGFloat

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
        var x: CGFloat = 0, y: CGFloat = 0, height: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width + 0.5 {
                x = 0
                y += height + line
                height = 0
            }
            rects.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + gap
            height = max(height, size.height)
        }
        return rects
    }
}
