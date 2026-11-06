import OpenspotCore
import SwiftUI

/// The sandbox: the text of a sheet on the left, and on the right the real sheet with its faults and what a person did.
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
            Rectangle().fill(.white.opacity(SpotTokens.fill)).frame(width: 1)
            result
        }
        .frame(width: Self.textWidth + Self.sideWidth + 1, height: Self.height)
        .background(Color(white: 0.16))
        .preferredColorScheme(.dark)
    }

    private var source: some View {
        VStack(alignment: .leading, spacing: SpotTokens.placeGap) {
            HStack {
                Text(model.fileName ?? "Sheet")
                    .font(SpotType.title)
                    .lineLimit(1)
                Spacer()
                if !model.isScript { examples }
            }
            .frame(height: SpotTokens.glyphSize)
            TextEditor(text: text)
                .font(Self.codeFont)
                .scrollContentBackground(.hidden)
                .disabled(model.isScript)
                .autocorrectionDisabled()
        }
        .padding(SpotTokens.padding)
        .frame(width: Self.textWidth)
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
            if let panel = model.sandbox.panel {
                SpotSheetPreview(panel: panel, onSet: { model.set($0, to: $1) }, onPress: { model.press($0) })
            } else {
                Text("Type a sheet, or choose an example.")
                    .font(SpotType.body)
                    .modifier(SpotSecondaryText())
                    .frame(width: SpotTokens.gridWidth, height: SpotTokens.glyphSize)
            }
            lines(model.sandbox.faults.isEmpty ? ["No faults"] : model.sandbox.faults, color: model.sandbox.faults.isEmpty ? .white.opacity(SpotTokens.secondaryLight) : .orange)
            if !model.sandbox.log.isEmpty {
                lines(model.sandbox.log, color: .white.opacity(SpotTokens.secondaryLight))
            }
            Spacer(minLength: 0)
        }
        .padding(SpotTokens.padding)
        .frame(width: Self.sideWidth, alignment: .topLeading)
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
