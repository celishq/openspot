import AppKit
import OpenspotCore
import SwiftUI

struct SpotThemeCell: View {
    let key: String
    let kind: ThemeKind
    let cell: ThemeRow.Cell
    let isLocked: Bool
    let model: SpotThemeModel

    private static let writePause: Duration = .milliseconds(500)

    @State private var number = 0.0
    @State private var colour = Color.clear
    @State private var pending: Task<Void, Never>?

    var body: some View {
        HStack(spacing: SpotTokens.menuPadding) {
            if isLocked { words } else { control }
            if !isLocked {
                Button { model.write(nil, of: key, in: cell.section) } label: { Image(systemName: "arrow.uturn.backward") }
                    .buttonStyle(.borderless)
                    .help("Use the value of \(ThemeFolder.builtInName)")
                    .opacity(cell.isSet ? 1 : MotionTokens.hiddenOpacity)
                    .disabled(!cell.isSet)
            }
        }
        .opacity(cell.isSet || isLocked ? 1 : SpotTheme.secondaryLight)
        .onAppear(perform: take)
        .onChange(of: cell.value) { take() }
    }

    @ViewBuilder
    private var words: some View {
        if kind == .colour {
            Circle().fill(colour).frame(width: SpotTokens.themeSwatch, height: SpotTokens.themeSwatch)
                .overlay { Circle().strokeBorder(.separator) }
        }
        Text(text).font(SpotType.body.monospacedDigit()).lineLimit(1)
    }

    @ViewBuilder
    private var control: some View {
        switch kind {
        case .colour:
            ColorPicker("", selection: Binding(get: { colour }, set: change), supportsOpacity: true)
                .labelsHidden()
            Text(text).font(SpotType.detail.monospacedDigit()).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 0)
        case .variant:
            Picker("", selection: Binding(get: { text }, set: { model.write(.string($0), of: key, in: cell.section) })) {
                Text("Clear").tag(Theme.Glass.Variant.clear.rawValue)
                Text("Regular").tag(Theme.Glass.Variant.regular.rawValue)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        case .strength:
            Slider(value: Binding(get: { number }, set: slide), in: kind.range) { isMoving in
                if !isMoving { write(kind.value(number)) }
            }
            .controlSize(.small)
            .frame(maxWidth: .infinity)
            Text(kind.value(number).number.map { $0.formatted(.number.precision(.fractionLength(2))) } ?? "")
                .font(SpotType.detail.monospacedDigit())
                .frame(width: SpotTokens.themeNumberWidth, alignment: .trailing)
        case .points, .reach, .seconds, .scale:
            TextField("", value: Binding(get: { number }, set: step), format: .number.precision(.fractionLength(0...2)))
                .multilineTextAlignment(.trailing)
                .frame(width: SpotTokens.themeNumberWidth)
            Stepper("", value: Binding(get: { number }, set: step), in: kind.range, step: kind.step)
                .labelsHidden()
        }
    }

    private var text: String {
        switch cell.value {
        case .string(let text): text
        case let value: value.number.map { $0.formatted(.number.precision(.fractionLength(0...2))) } ?? ""
        }
    }

    private func take() {
        number = cell.value.number ?? 0
        if case .string(let text) = cell.value, let color = ThemeColor(text: text) { colour = color.color }
    }

    private func slide(_ next: Double) {
        number = next
        model.preview(kind.value(next), of: key, in: cell.section)
    }

    private func step(_ next: Double) {
        number = next
        write(kind.value(next))
    }

    private func change(_ next: Color) {
        colour = next
        guard let rgb = NSColor(next).usingColorSpace(.sRGB) else { return }
        let value = ConfigDocument.Value.string(HexColor(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent, alpha: rgb.alphaComponent).text)
        model.preview(value, of: key, in: cell.section)
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: Self.writePause)
            guard !Task.isCancelled else { return }
            write(value)
        }
    }

    private func write(_ value: ConfigDocument.Value) {
        guard value != cell.value else { return }
        model.write(value, of: key, in: cell.section)
    }
}
