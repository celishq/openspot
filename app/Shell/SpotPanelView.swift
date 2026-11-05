import OpenspotCore
import SwiftUI

/// The parts that a script prints, drawn with system controls. It draws what it gets, and reports each change.
struct SpotPanelView: View {
    let panel: SpotPanel
    let onSet: (SpotPart, String) -> Void
    let onPress: (SpotPart) -> Void
    @FocusState private var focus: String?
    @Environment(\.spotIsShown) private var isShown

    private static let dividerGap: CGFloat = 8
    private static let swatchSize: CGFloat = 22
    private static let lineGap: CGFloat = 8

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SpotTokens.partGap) {
                ForEach(panel.parts) { part in
                    line(part)
                        .frame(height: SpotTokens.partHeight(part))
                }
            }
        }
        .onAppear(perform: focusFirstField)
        .onChange(of: isShown) { _, isShown in
            if isShown { DispatchQueue.main.asyncAfter(deadline: .now() + SpotMotion.fadeInDuration, execute: focusFirstField) }
        }
    }

    private func focusFirstField() {
        DispatchQueue.main.async { focus = panel.parts.first(where: \.isEditable)?.id }
    }

    @ViewBuilder
    private func line(_ part: SpotPart) -> some View {
        switch part.control {
        case .text(let text, _, let placeholder, let isReadOnly):
            textArea(part, text: text, placeholder: placeholder, isReadOnly: isReadOnly)
        case .slider(let level, let low, let high):
            slider(part, level: level, low: low, high: high)
        case .swatches(let colors, let value):
            swatches(part, colors: colors, value: value)
        default:
            if part.press == .line {
                Button { onPress(part) } label: { labelled(part).contentShape(Rectangle()) }
                    .buttonStyle(.plain)
            } else {
                labelled(part)
            }
        }
    }

    /// A line with a label, a value, a round button and a switch or a menu. A section with no title is a divider.
    private func labelled(_ part: SpotPart) -> some View {
        HStack(spacing: Self.lineGap) {
            if let symbol = part.symbol {
                Image(systemName: symbol).modifier(SpotSecondaryText())
            }
            if let title = part.title {
                Text(title)
                    .font(part.isSection ? SpotType.title : SpotType.body)
                    .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                    .lineLimit(1)
            }
            if part.isSection, part.title == nil {
                divider
            } else if part.title != nil || part.detail != nil {
                Spacer(minLength: Self.lineGap)
            }
            if let detail = part.detail ?? (part.press == .line ? part.key?.label : nil) {
                Text(detail)
                    .font(SpotType.detail)
                    .modifier(SpotSecondaryText())
                    .lineLimit(1)
            }
            if case .symbol(let symbol) = part.press {
                SpotRoundButton(symbol: symbol, label: part.title ?? part.id.capitalized) { onPress(part) }
            }
            control(part)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            if part.isSection, part.title != nil, part.id != panel.parts.first?.id { divider }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(SpotTokens.fill))
            .frame(height: 1)
    }

    @ViewBuilder
    private func control(_ part: SpotPart) -> some View {
        switch part.control {
        case .toggle(let on):
            Toggle(part.title ?? part.id, isOn: Binding(get: { on }, set: { onSet(part, $0 ? "true" : "false") }))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        case .menu(let options, let value):
            menu(part, options: options, value: value)
        default:
            EmptyView()
        }
    }

    private func menu(_ part: SpotPart, options: [SpotPart.Option], value: String?) -> some View {
        Menu {
            Picker(part.title ?? part.id, selection: Binding(get: { value ?? "" }, set: { onSet(part, $0) })) {
                ForEach(options, id: \.id) { Text($0.title).tag($0.id) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 4) {
                Text(options.first { $0.id == value }?.title ?? options.first?.title ?? "")
                    .font(SpotType.detail)
                    .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .modifier(SpotSecondaryText())
            }
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
    }

    private func slider(_ part: SpotPart, level: Double, low: Double, high: Double) -> some View {
        HStack(spacing: Self.lineGap) {
            if let title = part.title {
                Text(title)
                    .font(SpotType.body)
                    .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
            }
            if let symbol = part.symbol {
                Image(systemName: symbol)
                    .foregroundStyle(.white)
            }
            Slider(value: Binding(get: { level }, set: { onSet(part, String(Int($0.rounded()))) }), in: low...max(high, low + 1))
                .controlSize(.small)
                .tint(.white)
                .labelsHidden()
        }
    }

    private func swatches(_ part: SpotPart, colors: [String], value: String?) -> some View {
        HStack(spacing: Self.lineGap) {
            ForEach(colors, id: \.self) { color in
                Button { onSet(part, color) } label: {
                    Circle()
                        .fill(Self.color(color))
                        .frame(width: Self.swatchSize, height: Self.swatchSize)
                        .overlay {
                            if color == value { Circle().strokeBorder(.white, lineWidth: 2) }
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func color(_ text: String) -> Color {
        let value = Int(text.dropFirst(), radix: 16) ?? 0
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    @ViewBuilder
    private func textArea(_ part: SpotPart, text: String, placeholder: String?, isReadOnly: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            if isReadOnly {
                ScrollView(showsIndicators: false) {
                    Text(text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                TextEditor(text: Binding(get: { text }, set: { onSet(part, $0) }))
                    .scrollContentBackground(.hidden)
                    .focused($focus, equals: part.id)
                    .padding(.horizontal, -SpotTokens.editorInset)
            }
            if text.isEmpty, let placeholder {
                Text(placeholder)
                    .foregroundStyle(.white.opacity(SpotTokens.secondaryLight))
                    .allowsHitTesting(false)
            }
        }
        .font(SpotType.body)
        .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
        .padding(SpotTokens.padding)
        .background(Color.white.opacity(SpotTokens.fill), in: shape)
    }
}
