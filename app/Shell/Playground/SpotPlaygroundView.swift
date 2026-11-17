import OpenspotCore
import SwiftUI

struct SpotPlaygroundView: View {
    @Bindable var model: SpotPlaygroundModel

    private var text: Binding<String> {
        Binding(get: { model.source }, set: { model.edit($0) })
    }

    var body: some View {
        VStack(spacing: 0) {
            split
            SpotWindowFooter(hint: hint, tip: "Close the playground") {}
        }
        .ignoresSafeArea(edges: [.horizontal, .bottom])
        .modifier(SpotWindowSurface())
    }

    private var hint: String {
        if let name = model.fileName { return "Each edit saves to \(name) and runs the spot again." }
        return "Each edit runs the spot again. The spot ends with this window."
    }

    private var split: some View {
        VSplitView {
            HSplitView {
                source
                    .frame(minWidth: SpotTokens.playgroundTextWidth, idealWidth: SpotTokens.playgroundTextIdeal, maxHeight: .infinity)
                VStack(spacing: 0) {
                    SpotPlaygroundStage(model: model)
                    faults
                }
                .frame(minWidth: SpotTokens.playgroundStageWidth, idealWidth: SpotTokens.panelWidth, maxHeight: .infinity)
            }
            .frame(minHeight: SpotTokens.playgroundTopHeight, idealHeight: SpotTokens.playgroundTopIdeal)
            .layoutPriority(1)
            calls
                .frame(minHeight: SpotTokens.playgroundLogHeight, idealHeight: SpotTokens.playgroundLogHeight, maxHeight: .infinity)
        }
        .frame(minWidth: SpotTokens.playgroundTextWidth + SpotTokens.playgroundStageWidth, minHeight: SpotTokens.playgroundTopHeight + SpotTokens.playgroundLogHeight)
    }

    private var source: some View {
        VStack(alignment: .leading, spacing: SpotTokens.placeGap) {
            HStack {
                Text(model.fileName ?? "Spot")
                    .font(SpotType.title)
                    .lineLimit(1)
                Spacer()
                Button("Run again") { Task { await model.rerun() } }
                    .keyboardShortcut("r")
                presets
            }
            .frame(height: SpotTokens.glyph)
            TextEditor(text: text)
                .font(SpotType.code)
                .scrollContentBackground(.hidden)
                .autocorrectionDisabled()
        }
        .padding(SpotTokens.padding)
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

    private var faults: some View {
        let faults = (model.fault.map { [$0] } ?? []) + (model.lack.map { [$0] } ?? []) + model.playground.faults
        return VStack(alignment: .leading, spacing: SpotType.lineGap) {
            lines(faults.isEmpty ? ["No faults"] : faults, color: faults.isEmpty ? SpotTheme.ink.opacity(SpotTheme.secondary) : SpotTheme.warn)
            if !model.playground.log.isEmpty {
                lines(model.playground.log, color: SpotTheme.ink.opacity(SpotTheme.secondary))
            }
        }
        .padding(SpotTokens.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var calls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
                if model.playground.calls.isEmpty {
                    Text("Each call of the spot shows here: $ its arguments, < its stdin, > its frames, ! its stderr and = its end.")
                        .font(SpotType.code)
                        .modifier(SpotSecondaryText())
                }
                ForEach(Array(model.playground.calls.enumerated()), id: \.offset) { _, call in
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(call.lines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(SpotType.code)
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
    }

    private func color(of line: String) -> Color {
        switch line.first {
        case "$", "=": SpotTheme.ink
        case "!": SpotTheme.warn
        default: SpotTheme.ink.opacity(SpotTheme.secondary)
        }
    }

    private func lines(_ lines: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(SpotType.code)
                    .foregroundStyle(color)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
