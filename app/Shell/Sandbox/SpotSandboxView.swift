import OpenspotCore
import SwiftUI

/// The playground: the text of a spot on the left; on the right the place where it shows, its sheet, its card or its rows in
/// the main search, with its faults; and below them each call that the spot got, with what it printed.
struct SpotSandboxView: View {
    @Bindable var model: SpotSandboxModel

    private static let textWidth: CGFloat = 440
    private static let sideWidth: CGFloat = 360
    private static let height: CGFloat = 640
    private static let logHeight: CGFloat = 240
    private static let codeFont = Font.system(size: 12, design: .monospaced)

    private var text: Binding<String> {
        Binding(get: { model.source }, set: { model.edit($0) })
    }

    private var query: Binding<String> {
        Binding(get: { model.query }, set: { model.search($0) })
    }

    private var divider: some View {
        Rectangle().fill(SpotTheme.ink.opacity(SpotTheme.fill))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                source
                divider.frame(width: 1)
                result
            }
            .frame(height: Self.height)
            divider.frame(height: 1)
            calls
        }
        .frame(width: Self.textWidth + Self.sideWidth + 1, height: Self.height + Self.logHeight + 1)
        .background(SpotTheme.window)
    }

    private var source: some View {
        VStack(alignment: .leading, spacing: SpotTokens.placeGap) {
            HStack {
                Text(model.fileName ?? "Spot")
                    .font(SpotType.title)
                    .lineLimit(1)
                Spacer()
                Button("Run again") { model.rerun() }
                    .keyboardShortcut("r")
                presets
            }
            .frame(height: SpotTokens.glyphSize)
            TextEditor(text: text)
                .font(Self.codeFont)
                .scrollContentBackground(.hidden)
                .autocorrectionDisabled()
        }
        .padding(SpotTokens.padding)
        .frame(width: Self.textWidth)
    }

    private var presets: some View {
        Menu("Examples") {
            ForEach(Array(model.presets.enumerated()), id: \.offset) { _, preset in
                Button(preset.name) { model.edit(preset.text) }
            }
        }
        .menuStyle(.button)
        .fixedSize()
    }

    private var placeChoice: Binding<PlaygroundPlace> {
        Binding(get: { model.place }, set: { model.choose($0) })
    }

    private var result: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpotTokens.formFieldGap) {
                Picker("Place", selection: placeChoice) {
                    ForEach(PlaygroundPlace.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: SpotTokens.gridWidth)
                if model.place != .card {
                    TextField(model.place == .search ? "Search" : "Search the sheet", text: query)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: SpotTokens.gridWidth)
                }
                switch model.place {
                case .sheet: sheetView
                case .card: cardView
                case .search: searchView
                }
                let faults = (model.fault.map { [$0] } ?? []) + (model.lack.map { [$0] } ?? []) + model.sandbox.faults
                lines(faults.isEmpty ? ["No faults"] : faults, color: faults.isEmpty ? SpotTheme.ink.opacity(SpotTheme.secondaryLight) : .orange)
                if !model.sandbox.log.isEmpty {
                    lines(model.sandbox.log, color: SpotTheme.ink.opacity(SpotTheme.secondaryLight))
                }
            }
            .padding(SpotTokens.padding)
        }
        .frame(width: Self.sideWidth, alignment: .topLeading)
    }

    @ViewBuilder
    private var sheetView: some View {
        if let panel = model.panel {
            SpotSheetPreview(
                panel: panel,
                title: model.spot?.name ?? "Sheet",
                subtitle: model.spot?.subtitle ?? "",
                symbol: model.spot?.symbol ?? "square.dashed",
                onSet: { model.set($0, to: $1) },
                onPress: { model.press($0) },
                list: model.sheet?.list ?? ItemList()
            )
        } else {
            empty("Type a spot, or choose an example.")
        }
    }

    /// The card of the spot at its size: the drawing of its newest frame, or else its icon, title and detail.
    @ViewBuilder
    private var cardView: some View {
        if let spot = model.spot {
            let size = model.card?.size ?? spot.size
            let frame = CGSize(width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows))
            let shape = RoundedRectangle(cornerRadius: SpotTokens.corner(for: size), style: .continuous)
            Group {
                if let card = model.card {
                    SpotCardDrawing(layout: card.layout, face: card.face, card: card.size) { _, _ in }
                } else {
                    VStack(alignment: .leading, spacing: SpotType.lineGap) {
                        Image(systemName: spot.symbol).font(.system(size: 17, weight: .semibold))
                        Spacer(minLength: 0)
                        Text(model.sheet?.state.title ?? spot.name).font(SpotType.title).lineLimit(1)
                        if let detail = model.sheet?.state.subtitle ?? spot.subtitle {
                            Text(detail).font(SpotType.detail).modifier(SpotSecondaryText()).lineLimit(1)
                        }
                    }
                    .foregroundStyle(SpotTheme.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .padding(SpotTokens.cardPadding(for: size, isWidget: true))
            .frame(width: frame.width, height: frame.height)
            .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
        } else {
            empty("Type a spot, or choose an example.")
        }
    }

    /// The rows that the spot gives to the text of the main search, as the panel lists them.
    @ViewBuilder
    private var searchView: some View {
        if model.answers.isEmpty {
            empty(model.query.isEmpty ? "Type a text in the search." : "No rows for this text.")
        } else {
            SpotRowsView(list: ItemList(items: model.answers), onRun: { _ in })
                .frame(width: SpotTokens.gridWidth, height: CGFloat(model.answers.count) * SpotTokens.listRowHeight)
        }
    }

    private func empty(_ text: String) -> some View {
        Text(text)
            .font(SpotType.body)
            .modifier(SpotSecondaryText())
            .frame(width: SpotTokens.gridWidth, height: SpotTokens.glyphSize, alignment: .leading)
    }

    private var calls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
                if model.sandbox.calls.isEmpty {
                    Text("Each call of the spot shows here: $ its arguments, < its stdin, > its frames, ! its stderr and = its end.")
                        .font(Self.codeFont)
                        .modifier(SpotSecondaryText())
                }
                ForEach(Array(model.sandbox.calls.enumerated()), id: \.offset) { _, call in
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(call.lines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(Self.codeFont)
                                .foregroundStyle(color(of: line))
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SpotTokens.padding)
        }
        .frame(height: Self.logHeight)
    }

    /// The colour of a line of a call, by its mark: the call and its end in ink, stderr in orange, the rest secondary.
    private func color(of line: String) -> Color {
        switch line.first {
        case "$", "=": SpotTheme.ink
        case "!": .orange
        default: SpotTheme.ink.opacity(SpotTheme.secondaryLight)
        }
    }

    private func lines(_ lines: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(Self.codeFont)
                    .foregroundStyle(color)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: SpotTokens.gridWidth, alignment: .leading)
    }
}
