import OpenspotCore
import SwiftUI

/// One slot of a row: a picture, words, a mark or a control, drawn small enough for a line.
struct SpotSlotView: View {
    let part: SpotPart
    var tone: MetricValue.Tone?
    let onSlot: (String, String?) -> Void

    var body: some View {
        switch part.control {
        case .toggle(let on) where part.look == .tick:
            SpotTick(isOn: on, words: words) { onSlot(part.id, $0 ? "true" : "false") }
        case .toggle(let on):
            let toggle = Toggle("", isOn: Binding(get: { on }, set: { onSlot(part.id, $0 ? "true" : "false") }))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .tint(SpotTheme.ink)
            ViewThatFits(in: .horizontal) {
                if part.title != nil || part.detail != nil {
                    HStack(spacing: 8) {
                        words.fixedSize()
                        Spacer(minLength: 0)
                        toggle
                    }
                }
                toggle
            }
        case .slider(let level, let low, let high):
            SpotSlotSlider(level: level, low: low, high: high) { onSlot(part.id, String(Int($0.rounded()))) }
        case .menu(let options, let value), .list(let options, let value):
            Menu(options.first { $0.id == value }?.title ?? part.title ?? "") {
                ForEach(options, id: \.id) { option in
                    Button(option.title) { onSlot(part.id, option.id) }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        case .progress(let level):
            ProgressView(value: min(max(level, 0), 100), total: 100)
                .progressViewStyle(.linear)
                .tint(SpotTheme.ink)
                .controlSize(.small)
        case .chart(let points):
            VStack(alignment: .leading, spacing: SpotType.lineGap) {
                if part.title != nil || part.detail != nil { words.fixedSize(horizontal: false, vertical: true) }
                SpotSlotBars(points: points)
            }
        case .shortcut(let text):
            SpotKeyLabel(text: text, isRecording: false)
        case .text(let text, let placeholder, let isReadOnly):
            SpotSlotField(text: text, placeholder: placeholder ?? part.title ?? "", isReadOnly: isReadOnly) { onSlot(part.id, $0) }
        case .metric(let number):
            VStack(alignment: .leading, spacing: SpotType.lineGap) {
                Text(number)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let label = part.title {
                    Text(label).font(SpotType.detail).modifier(SpotSecondaryText()).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        case .image(let path):
            picture(icon: .image(path))
        default:
            if part.kind == "picture" {
                picture(icon: part.file.map(FileIcon.init(path:)))
            } else if case .symbol(let symbol) = part.press {
                Button { onSlot(part.id, nil) } label: {
                    Image(systemName: symbol)
                        .font(SpotType.body.weight(.semibold))
                        .foregroundStyle(SpotTheme.ink)
                        .frame(width: 28, height: 28)
                        .background(SpotTheme.ink.opacity(SpotTheme.chip), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(part.title ?? part.id.capitalized)
            } else if part.press == .line {
                Button { onSlot(part.id, nil) } label: {
                    Text(part.title ?? part.id.capitalized)
                        .font(SpotType.action)
                        .foregroundStyle(SpotTheme.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(SpotTheme.ink.opacity(SpotTheme.chip), in: Capsule())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                words
            }
        }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            if let title = part.title {
                Text(title).font(SpotType.body).foregroundStyle(SpotTheme.ink).lineLimit(1)
            }
            if let detail = part.detail {
                Text(detail).font(SpotType.detail).modifier(SpotSecondaryText()).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func picture(icon: FileIcon?) -> some View {
        GeometryReader { room in
            let side = SpotTokens.pictureSide(in: room.size)
            SpotItemIcon(icon: icon, glyph: part.glyph, symbol: part.symbol, size: side)
                .overlay(alignment: .bottomTrailing) { SpotToneDot(tone: tone, side: side) }
                .frame(width: room.size.width, height: room.size.height)
        }
    }
}

/// A text field in a row, which sends its text when the person presses Return.
private struct SpotSlotField: View {
    let text: String
    let placeholder: String
    let isReadOnly: Bool
    let onSubmit: (String) -> Void
    @State private var typed: String?

    var body: some View {
        TextField(placeholder, text: Binding(get: { typed ?? text }, set: { typed = $0 }))
            .textFieldStyle(.plain)
            .font(SpotType.body)
            .foregroundStyle(SpotTheme.ink)
            .disabled(isReadOnly)
            .onSubmit {
                if let typed { onSubmit(typed) }
                typed = nil
            }
    }
}

/// A slider in a row, which sends its value once the person lets go.
private struct SpotSlotSlider: View {
    let level: Double
    let low: Double
    let high: Double
    let onEnd: (Double) -> Void
    @State private var dragged: Double?

    var body: some View {
        Slider(value: Binding(get: { dragged ?? level }, set: { dragged = $0 }), in: low...high) { editing in
            if !editing, let dragged { onEnd(dragged); self.dragged = nil }
        }
        .controlSize(.small)
        .tint(SpotTheme.ink)
    }
}

/// Bars in a row. The last bar is the newest.
private struct SpotSlotBars: View {
    let points: [Double]

    var body: some View {
        let top = max(points.max() ?? 1, 1)
        GeometryReader { room in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
                        .frame(height: room.size.height * max(point, 0) / top)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}
