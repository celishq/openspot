import OpenspotCore
import SwiftUI

/// The rows of a script, one on each line or as square buttons, which scroll when they do not fit.
struct SpotRowsView: View {
    let list: ItemList
    let onRun: (SpotItem) -> Void
    @State private var edges = SpotScrollEdges()

    private static let bottomFade = 2 * SpotTokens.padding

    private var row: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
    }

    private var isGrid: Bool {
        list.perLine > 1
    }

    var body: some View {
        if list.shown.isEmpty {
            Text(emptyText)
                .font(SpotType.body)
                .modifier(SpotSecondaryText())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            scroll
        }
    }

    private var emptyText: String {
        if list.isWaiting { return "Searching" }
        if list.isLoading { return "Loading…" }
        if list.hasFailed { return "Could not load" }
        if list.search == .script && list.query.isEmpty { return "Type to search" }
        return list.query.isEmpty ? "Nothing here yet" : "No results"
    }

    private var scroll: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                if isGrid { buttons } else { lines }
            }
            .safeAreaPadding(.top, SpotTokens.padding)
            .safeAreaPadding(.bottom, SpotTokens.sheetFits(rows: list.shown.count, perLine: list.perLine) ? SpotTokens.padding : Self.bottomFade)
            .modifier(SpotScrollEdgeTracker(edges: $edges))
            .mask(edgeFade)
            .padding(.vertical, -SpotTokens.padding)
            .onChange(of: list.selectedItem?.run) { _, run in
                if let run { proxy.scrollTo(run) }
            }
            .onChange(of: list.query) {
                guard let run = list.shown.first?.run else { return }
                DispatchQueue.main.async { proxy.scrollTo(run, anchor: .top) }
            }
        }
    }

    private var lines: some View {
        LazyVStack(spacing: SpotTokens.listRowGap) {
            ForEach(Array(list.shown.enumerated()), id: \.element.run) { index, item in
                Button {
                    onRun(item)
                } label: {
                    rowLabel(item, isSelected: index == list.selected)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var buttons: some View {
        let side = SpotTokens.square(perLine: list.perLine)
        let columns = Array(repeating: GridItem(.fixed(side), spacing: SpotTokens.listRowGap), count: list.perLine)
        return LazyVGrid(columns: columns, spacing: SpotTokens.listRowGap) {
            ForEach(Array(list.shown.enumerated()), id: \.element.run) { index, item in
                Button {
                    onRun(item)
                } label: {
                    SpotItemIcon(item: item, size: SpotTokens.listIconSize)
                        .frame(width: side, height: side)
                        .background(Color.white.opacity(index == list.selected ? SpotTokens.selectedFill : SpotTokens.fill), in: row)
                        .contentShape(row)
                }
                .buttonStyle(.plain)
                .help(item.title)
                .accessibilityLabel(item.title)
            }
        }
    }

    private var edgeFade: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(1 - edges.top), .black], startPoint: .top, endPoint: .bottom)
                .frame(height: SpotTokens.padding)
            Color.black
            LinearGradient(colors: [.black, .black.opacity(1 - edges.bottom)], startPoint: .top, endPoint: .bottom)
                .frame(height: Self.bottomFade)
        }
    }

    private func rowLabel(_ item: SpotItem, isSelected: Bool) -> some View {
        HStack(spacing: SpotTokens.padding - 5) {
            SpotItemIcon(item: item, size: SpotTokens.listIconSize)
            VStack(alignment: .leading, spacing: SpotType.lineGap) {
                Text(item.title)
                    .font(SpotType.body)
                    .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                    .lineLimit(1)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(SpotType.detail)
                        .modifier(SpotSecondaryText())
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SpotTokens.padding)
        .frame(height: SpotTokens.listRowHeight)
        .background(Color.white.opacity(isSelected ? SpotTokens.selectedFill : SpotTokens.fill), in: row)
        .contentShape(row)
    }
}
