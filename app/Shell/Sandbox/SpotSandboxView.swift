import OpenspotCore
import SwiftUI

/// The sandbox: the text of a sheet on the left, and on the right the real sheet with its faults and what a person did. A
/// Try of a spot shows its card at each size and the log of its calls on the left, in place of the text.
struct SpotSandboxView: View {
    @Bindable var model: SpotSandboxModel

    private static let textWidth: CGFloat = 400
    private static let sideWidth: CGFloat = 340
    private static let height: CGFloat = 640
    private static let codeFont = Font.system(size: 12, design: .monospaced)

    private var text: Binding<String> {
        Binding(get: { model.sandbox.text }, set: { model.edit($0) })
    }

    var body: some View {
        HStack(spacing: 0) {
            source
            Rectangle().fill(SpotTheme.ink.opacity(SpotTheme.fill)).frame(width: 1)
            result
        }
        .frame(width: Self.textWidth + Self.sideWidth + 1, height: Self.height)
        .background(SpotTheme.window)
    }

    private var source: some View {
        VStack(alignment: .leading, spacing: SpotTokens.placeGap) {
            HStack {
                Text(model.card?.command.name ?? model.fileName ?? "Sheet")
                    .font(SpotType.title)
                    .lineLimit(1)
                Spacer()
                if !model.isScript { examples }
            }
            .frame(height: SpotTokens.glyphSize)
            if let card = model.card, let spots = model.spots {
                cards(of: card, in: spots)
                calls
            } else {
                TextEditor(text: text)
                    .font(Self.codeFont)
                    .scrollContentBackground(.hidden)
                    .disabled(model.isScript)
                    .autocorrectionDisabled()
            }
        }
        .padding(SpotTokens.padding)
        .frame(width: Self.textWidth)
    }

    /// The card of the spot at each size it takes: the one-row sizes side by side, then each larger one.
    private func cards(of card: SpotsModel.Entry, in spots: SpotsModel) -> some View {
        let sizes = card.command.sizes.isEmpty ? [card.size] : [SpotSize.small, .wide, .square, .strip].filter(card.command.sizes.contains)
        let narrow = sizes.filter { $0.rows == 1 && $0.columns < SpotTokens.columns }
        return VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            HStack(alignment: .top, spacing: SpotTokens.columnGap) {
                ForEach(narrow, id: \.name) { size in self.card(card, size, spots) }
            }
            ForEach(sizes.filter { !narrow.contains($0) }, id: \.name) { size in self.card(card, size, spots) }
        }
        .environment(\.spotIsShown, true)
    }

    private func card(_ card: SpotsModel.Entry, _ size: SpotSize, _ spots: SpotsModel) -> some View {
        SpotCardView(entry: card, size: size, index: -1, isPressed: false, takesDrag: false, isDropTarget: false, chainLetter: nil, showsChain: false, isHiddenFromGrid: false, model: spots)
    }

    private var examples: some View {
        Menu("Examples") {
            ForEach(SheetExamples.all, id: \.name) { example in
                Button(example.name) { model.edit(example.text) }
            }
        }
        .menuStyle(.button)
        .fixedSize()
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: SpotTokens.formFieldGap) {
            if let panel = model.panel {
                SpotSheetPreview(panel: panel, title: model.card?.command.name ?? "Sheet", subtitle: model.card.map { $0.command.subtitle ?? "" } ?? "Preview", symbol: model.card?.command.symbol ?? "square.dashed", onSet: { model.set($0, to: $1) }, onPress: { model.press($0) })
            } else {
                Text("Type a sheet, or choose an example.")
                    .font(SpotType.body)
                    .modifier(SpotSecondaryText())
                    .frame(width: SpotTokens.gridWidth, height: SpotTokens.glyphSize)
            }
            lines(model.sandbox.faults.isEmpty ? ["No faults"] : model.sandbox.faults, color: model.sandbox.faults.isEmpty ? SpotTheme.ink.opacity(SpotTheme.secondaryLight) : .orange)
            if model.card == nil, !model.sandbox.log.isEmpty {
                lines(model.sandbox.log, color: SpotTheme.ink.opacity(SpotTheme.secondaryLight))
            }
            Spacer(minLength: 0)
        }
        .padding(SpotTokens.padding)
        .frame(width: Self.sideWidth, alignment: .topLeading)
    }

    /// The log of the calls of the spot that is tried, the newest at the bottom.
    private var calls: some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            Text("Calls")
                .font(SpotType.detail)
                .modifier(SpotSecondaryText())
            ScrollView {
                Text(model.calls.isEmpty ? "No calls yet. Use the sheet or the card, and each call shows here." : model.calls)
                    .font(Self.codeFont)
                    .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .defaultScrollAnchor(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
