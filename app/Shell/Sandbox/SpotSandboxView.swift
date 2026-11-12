import OpenspotCore
import SwiftUI

/// The playground: the text of a spot on the left; on the right the place where it shows, its sheet, its card or its rows in
/// the main search, on the panel's glass, with its faults; and below them each call that the spot got, with what it
/// printed. A drag of a divider resizes each pane, and nothing keeps the sizes.
struct SpotSandboxView: View {
    @Bindable var model: SpotSandboxModel

    private static let minTextWidth: CGFloat = 320
    private static let minStageWidth: CGFloat = SpotTokens.gridWidth + 2 * SpotTokens.padding
    private static let minTopHeight: CGFloat = 360
    private static let minLogHeight: CGFloat = 120
    private static let codeFont = Font.system(size: 12, design: .monospaced)

    private var text: Binding<String> {
        Binding(get: { model.source }, set: { model.edit($0) })
    }

    var body: some View {
        VSplitView {
            HSplitView {
                source
                    .frame(minWidth: Self.minTextWidth, idealWidth: 440, maxHeight: .infinity)
                    .background(SpotTheme.window)
                VStack(spacing: 0) {
                    SpotPlaygroundStage(model: model)
                    faults
                }
                .frame(minWidth: Self.minStageWidth, idealWidth: SpotTokens.panelWidth, maxHeight: .infinity)
            }
            .frame(minHeight: Self.minTopHeight, idealHeight: SpotTokens.panelHeight + 120)
            .layoutPriority(1)
            calls
                .frame(minHeight: Self.minLogHeight, idealHeight: Self.minLogHeight, maxHeight: .infinity)
                .background(SpotTheme.window)
        }
        .frame(minWidth: Self.minTextWidth + Self.minStageWidth, minHeight: Self.minTopHeight + Self.minLogHeight)
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

    /// The faults of the spot and what the person did to it, under the stage on the window's own background.
    private var faults: some View {
        let faults = (model.fault.map { [$0] } ?? []) + (model.lack.map { [$0] } ?? []) + model.sandbox.faults
        return VStack(alignment: .leading, spacing: SpotType.lineGap) {
            lines(faults.isEmpty ? ["No faults"] : faults, color: faults.isEmpty ? SpotTheme.ink.opacity(SpotTheme.secondaryLight) : .orange)
            if !model.sandbox.log.isEmpty {
                lines(model.sandbox.log, color: SpotTheme.ink.opacity(SpotTheme.secondaryLight))
            }
        }
        .padding(SpotTokens.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SpotTheme.window)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
