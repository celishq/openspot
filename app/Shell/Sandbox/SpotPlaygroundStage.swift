import OpenspotCore
import SwiftUI

/// The right pane of the playground: the spot in the place that the person picked, drawn by the panel's own views on the
/// panel's glass over the desktop. A sheet is the sheet of a float, a card lies on a piece of the panel, and the main
/// search is the field with the rows that the spot answers.
struct SpotPlaygroundStage: View {
    @Bindable var model: SpotSandboxModel
    @FocusState private var isSearching: Bool

    private static let gap: CGFloat = 20

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(spacing: Self.gap) {
                Picker("Place", selection: Binding(get: { model.place }, set: { model.choose($0) })) {
                    ForEach(PlaygroundPlace.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                switch model.place {
                case .sheet: sheet
                case .card: card
                case .search: search
                }
            }
            .padding(Self.gap)
            .frame(maxWidth: .infinity)
        }
        .background(Color.black.opacity(0.001))
        .environment(\.spotIsShown, true)
    }

    private var title: String {
        model.sheet?.state.title ?? model.spot?.name ?? "Spot"
    }

    private var detail: String? {
        model.sheet?.state.subtitle ?? model.spot?.subtitle
    }

    private var symbol: String {
        model.spot?.symbol ?? "square.dashed"
    }

    private var searchField: some View {
        SpotSearchField(prompt: model.place == .search ? "Search" : "Search \(title)", text: model.query, onSearch: { model.search($0) }, isFocused: $isSearching)
    }

    /// The sheet as a float draws it: its header, its search, then its parts or its rows.
    @ViewBuilder
    private var sheet: some View {
        if let run = model.sheet {
            let size = SpotTokens.floatSize(rows: run.shape.rows, perLine: run.shape.perLine, parts: run.panel)
            VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
                header
                if let parts = run.panel {
                    SheetPartsView(
                        panel: parts,
                        work: { run.work(of: $0) },
                        onSet: { model.set($0, to: $1) },
                        onPress: { model.press($0) },
                        list: run.list,
                        selection: { run.selection },
                        selectedPart: { run.selectedPart?.id },
                        nudge: { run.nudge }
                    )
                } else {
                    searchField
                    SpotRowsView(list: run.list, onRun: { model.pick($0) }, selection: { run.selection })
                }
            }
            .padding(SpotTokens.padding)
            .frame(width: size.width, height: size.height + (run.panel == nil ? SpotTokens.menuRowHeight + SpotTokens.rowGap : 0), alignment: .topLeading)
            .modifier(SpotGlass())
        } else {
            empty
        }
    }

    private var header: some View {
        HStack(spacing: SpotTokens.padding - 5) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SpotTheme.ink)
                .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
                .background(SpotTheme.ink.opacity(SpotTheme.disc), in: Circle())
            VStack(alignment: .leading, spacing: SpotType.lineGap) {
                Text(title).font(SpotType.title).foregroundStyle(SpotTheme.ink).lineLimit(1)
                if let detail { Text(detail).font(SpotType.detail).modifier(SpotSecondaryText()).lineLimit(1) }
            }
            Spacer(minLength: 0)
            SpotRoundButton(symbol: "xmark", label: "Close") {}
        }
    }

    /// The card at its size on a piece of the panel's glass, drawn from its newest frame, or else its icon, title and detail.
    @ViewBuilder
    private var card: some View {
        if let spot = model.spot {
            let size = model.card?.size ?? spot.size
            let frame = CGSize(width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows))
            let shape = RoundedRectangle(cornerRadius: SpotTokens.corner(for: size), style: .continuous)
            Group {
                if let card = model.card {
                    SpotCardDrawing(layout: card.layout, face: card.face, card: card.size) { _, _ in }
                } else {
                    VStack(alignment: .leading, spacing: SpotType.lineGap) {
                        Image(systemName: symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
                            .background(SpotTheme.ink.opacity(SpotTheme.disc), in: Circle())
                        Spacer(minLength: 0)
                        Text(title).font(SpotType.title).lineLimit(1)
                        if let detail { Text(detail).font(SpotType.detail).modifier(SpotSecondaryText()).lineLimit(1) }
                    }
                    .foregroundStyle(SpotTheme.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .padding(SpotTokens.cardPadding(for: size, isWidget: true))
            .frame(width: frame.width, height: frame.height)
            .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
            .padding(SpotTokens.padding)
            .frame(width: SpotTokens.gridWidth + 2 * SpotTokens.padding, alignment: .leading)
            .modifier(SpotGlass())
        } else {
            empty
        }
    }

    /// The main search: its field, then the rows that the spot answers to its text.
    private var search: some View {
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            searchField
            if model.answers.isEmpty {
                Text(model.query.isEmpty ? "Type a text that the spot answers." : "No rows for this text.")
                    .font(SpotType.body)
                    .modifier(SpotSecondaryText())
                    .frame(height: SpotTokens.listRowHeight)
            } else {
                SpotRowsView(list: ItemList(items: model.answers), onRun: { model.pick($0) })
                    .frame(height: CGFloat(model.answers.count) * (SpotTokens.listRowHeight + SpotTokens.listRowGap))
            }
        }
        .padding(SpotTokens.padding)
        .frame(width: SpotTokens.gridWidth + 2 * SpotTokens.padding, alignment: .topLeading)
        .modifier(SpotGlass())
    }

    private var empty: some View {
        Text("Type a spot, or choose an example.")
            .font(SpotType.body)
            .modifier(SpotSecondaryText())
            .padding(SpotTokens.padding)
            .frame(width: SpotTokens.gridWidth, alignment: .leading)
            .modifier(SpotGlass())
    }
}
