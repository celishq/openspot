import OpenspotCore
import SwiftUI

/// The playground: the text of a spot on the left; its live sheet, its card and its faults on the right; and below them
/// each call that the spot got, with what it printed.
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

    private var result: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpotTokens.formFieldGap) {
                TextField("Search the sheet", text: query)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: SpotTokens.gridWidth)
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
                    Text("Type a spot, or choose an example.")
                        .font(SpotType.body)
                        .modifier(SpotSecondaryText())
                        .frame(width: SpotTokens.gridWidth, height: SpotTokens.glyphSize, alignment: .leading)
                }
                if let card = model.card { cardView(card) }
                let faults = (model.fault.map { [$0] } ?? []) + model.sandbox.faults
                lines(faults.isEmpty ? ["No faults"] : faults, color: faults.isEmpty ? SpotTheme.ink.opacity(SpotTheme.secondaryLight) : .orange)
                if !model.sandbox.log.isEmpty {
                    lines(model.sandbox.log, color: SpotTheme.ink.opacity(SpotTheme.secondaryLight))
                }
            }
            .padding(SpotTokens.padding)
        }
        .frame(width: Self.sideWidth, alignment: .topLeading)
    }

    private func cardView(_ card: (layout: WidgetLayout, face: CardFace, size: SpotSize)) -> some View {
        let size = CGSize(width: SpotTokens.width(columns: card.size.columns), height: SpotTokens.height(rows: card.size.rows))
        let shape = RoundedRectangle(cornerRadius: SpotTokens.corner(for: card.size), style: .continuous)
        return SpotCardDrawing(layout: card.layout, face: card.face, card: card.size) { _, _ in }
            .padding(SpotTokens.cardPadding(for: card.size, isWidget: true))
            .frame(width: size.width, height: size.height)
            .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
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
