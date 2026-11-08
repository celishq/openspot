import OpenspotCore
import SwiftUI

/// The rows of a script, one on each line or as square buttons, which scroll when they do not fit.
struct SpotRowsView: View {
    let list: ItemList
    var recording: String?
    let onRun: (SpotItem) -> Void
    @State private var edges = SpotScrollEdges()
    @State private var position = ScrollPosition(edge: .top)
    @State private var reading = GridScrollReading()

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
                .transition(.identity)
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
        Group {
            if isGrid { gridScroll } else { lineScroll }
        }
        .modifier(SpotScrollEdgeTracker(edges: $edges))
        .mask(edgeFade)
        .padding(.vertical, -SpotTokens.padding)
    }

    private var bottomInset: CGFloat {
        SpotTokens.sheetFits(rows: list.shown.count, perLine: list.perLine) ? SpotTokens.padding : Self.bottomFade
    }

    private var lineScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) { lines }
                .safeAreaPadding(.top, SpotTokens.padding)
                .safeAreaPadding(.bottom, bottomInset)
                .onChange(of: list.selectedItem?.run) { _, run in
                    if let run { proxy.scrollTo(run) }
                }
                .onChange(of: list.query) {
                    guard let run = list.shown.first?.run else { return }
                    DispatchQueue.main.async { proxy.scrollTo(run, anchor: .top) }
                }
        }
    }

    /// The grid, which scrolls by offsets worked out from the index of the selected cell, with its margins inside.
    private var gridScroll: some View {
        ScrollView(showsIndicators: false) {
            buttons
                .padding(.top, SpotTokens.padding)
                .padding(.bottom, bottomInset)
        }
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGSize.self, of: { CGSize(width: $0.containerSize.height, height: $0.contentSize.height) }, action: { _, size in
            reading.viewHeight = size.width
            reading.contentHeight = size.height
        })
        .onScrollPhaseChange { _, phase, context in
            if phase == .idle { reading.aim = context.geometry.contentOffset.y }
        }
        .onChange(of: list.selected) { showSelected() }
        .onChange(of: list.query) {
            reading.aim = 0
            position.scrollTo(y: 0)
        }
    }

    /// Scrolls the grid until the line of the selected cell lies clear of the fades at its two ends.
    private func showSelected() {
        guard reading.viewHeight > 0 else { return }
        let side = SpotTokens.square(perLine: list.perLine)
        let top = SpotTokens.padding + CGFloat(list.selected / list.perLine) * (side + SpotTokens.listRowGap)
        let window = ScrollWindow(
            top: SpotTokens.padding,
            bottom: reading.viewHeight - Self.bottomFade,
            viewHeight: reading.viewHeight,
            contentHeight: reading.contentHeight
        )
        let offset = window.offset(showing: top...(top + side), from: reading.aim)
        guard offset != reading.aim else { return }
        reading.aim = offset
        withAnimation(SpotMotion.arrowScroll) { position.scrollTo(y: offset) }
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
            ForEach(list.shown.indices, id: \.self) { index in
                let item = list.shown[index]
                Button {
                    onRun(item)
                } label: {
                    SpotGridCell(item: item, side: side).equatable()
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .topLeading) { ring(side: side) }
    }

    /// The one ring of the grid, over the selected cell, so that a new selection redraws no cell.
    @ViewBuilder
    private func ring(side: CGFloat) -> some View {
        if list.selectedItem != nil {
            let step = side + SpotTokens.listRowGap
            Color.clear
                .frame(width: side, height: side)
                .modifier(SpotSelectionRing(isSelected: true, shape: row, width: SpotSelectionRing<RoundedRectangle>.thinWidth))
                .offset(x: CGFloat(list.selected % list.perLine) * step, y: CGFloat(list.selected / list.perLine) * step)
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
        let marks = SearchQuery(text: list.query).marks(in: item)
        return HStack(spacing: SpotTokens.padding - 5) {
            SpotItemIcon(item: item, size: SpotTokens.listIconSize)
            VStack(alignment: .leading, spacing: SpotType.lineGap) {
                SpotMarkedText(text: item.title, marks: marks.title, font: SpotType.body, ink: SpotTheme.ink)
                if let subtitle = item.subtitle {
                    SpotMarkedText(text: subtitle, marks: marks.subtitle, font: SpotType.detail, ink: SpotTheme.ink, strength: SpotTheme.secondaryLight)
                }
            }
            Spacer(minLength: 0)
            if let shortcut = item.shortcut {
                SpotKeyLabel(text: shortcut, isRecording: recording == item.run)
            }
            if item.isOn {
                Image(systemName: "checkmark")
                    .font(SpotType.body.weight(.semibold))
                    .foregroundStyle(SpotTheme.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SpotTokens.padding)
        .frame(height: SpotTokens.listRowHeight)
        .background(SpotTheme.ink.opacity(SpotTheme.fill), in: row)
        .modifier(SpotSelectionRing(isSelected: isSelected, shape: row))
        .contentShape(row)
    }
}

/// One square of the grid. It depends on its item alone, so that a move of the selection leaves it as it is.
private struct SpotGridCell: View, Equatable {
    let item: SpotItem
    let side: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
        SpotItemIcon(item: item, size: SpotTokens.listIconSize)
            .frame(width: side, height: side)
            .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
            .contentShape(shape)
            .accessibilityLabel(item.title)
    }
}

/// What the grid last knew of its scroll view, kept out of observation so that a scroll redraws nothing.
@MainActor
private final class GridScrollReading {
    var viewHeight: CGFloat = 0
    var contentHeight: CGFloat = 0
    var aim: CGFloat = 0
}
