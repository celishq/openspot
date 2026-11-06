import AppKit
import OpenspotCore
import SwiftUI

/// The parts that a script prints, drawn with system controls where `SheetPlacement` puts them. It draws what it gets,
/// and reports each change.
struct SpotPanelView: View {
    let panel: SpotPanel
    var work: (SpotPart) -> ScriptCall? = { _ in nil }
    let onSet: (SpotPart, String) -> Void
    let onPress: (SpotPart) -> Void
    var recordingPart: String?
    var onRecord: (SpotPart) -> Void = { _ in }
    @FocusState private var focus: String?
    @Environment(\.spotIsShown) private var isShown

    private static let swatchSize: CGFloat = 22
    private static let smallSwatch: CGFloat = 16
    private static let lineGap: CGFloat = 8
    private static let barGap: CGFloat = 3
    private static let narrowCell: CGFloat = 80
    private static let narrowGap: CGFloat = 2
    private static let keyFont = Font.system(size: 18, weight: .medium)
    private static let metricFont = Font.system(size: 24, weight: .semibold, design: .rounded).monospacedDigit()
    private static let topFill = Color(white: 0.34).opacity(0.72)

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
    }

    var body: some View {
        let sheet = panel.placement
        Group {
            if sheet.overflows {
                ScrollView(showsIndicators: false) { canvas(sheet) }
            } else {
                canvas(sheet)
            }
        }
        .onAppear(perform: focusFirstField)
        .onChange(of: isShown) { _, isShown in
            if isShown { DispatchQueue.main.asyncAfter(deadline: .now() + SpotMotion.fadeInDuration, execute: focusFirstField) }
        }
    }

    private func canvas(_ sheet: SheetPlacement) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(sheet.cards.enumerated()), id: \.offset) { _, card in
                shape.fill(Color.white.opacity(SpotTokens.fill))
                    .frame(width: card.width, height: card.height)
                    .offset(x: card.minX, y: card.minY)
            }
            ForEach(Array(sheet.lines.enumerated()), id: \.offset) { _, line in
                Rectangle()
                    .fill(.white.opacity(SpotTokens.fill))
                    .frame(width: line.width, height: line.height)
                    .offset(x: line.minX, y: line.minY)
            }
            ForEach(panel.parts) { part in
                if let frame = sheet.frames[part.id] {
                    placed(part, frame)
                }
            }
        }
        .frame(width: SheetPlacement.width, height: sheet.height, alignment: .topLeading)
    }

    private func placed(_ part: SpotPart, _ frame: SheetPlacement.Frame) -> some View {
        content(part, frame)
            .frame(
                maxWidth: frame.horizontal == .fill ? .infinity : nil,
                maxHeight: frame.vertical == .fill ? .infinity : nil,
                alignment: .leading
            )
            .frame(width: frame.rect.width, height: frame.rect.height, alignment: Self.alignment(frame))
            .background {
                if isSelected(part), part.look != .tile {
                    shape.fill(Color.white.opacity(SpotTokens.selectedFill)).padding(-SpotTokens.controlPadding)
                }
            }
            .offset(x: frame.rect.minX, y: frame.rect.minY)
            .zIndex(frame.isOnTop ? 1 : 0)
    }

    private func isSelected(_ part: SpotPart) -> Bool {
        panel.selectedPart?.id == part.id
    }

    private static func alignment(_ frame: SheetPlacement.Frame) -> Alignment {
        let horizontal: HorizontalAlignment = switch frame.horizontal {
        case .fill, .start: .leading
        case .center: .center
        case .end: .trailing
        }
        let vertical: VerticalAlignment = switch frame.vertical {
        case .fill, .center: .center
        case .start: .top
        case .end: .bottom
        }
        return Alignment(horizontal: horizontal, vertical: vertical)
    }

    private func focusFirstField() {
        DispatchQueue.main.async { focus = panel.parts.first(where: \.isEditable)?.id }
    }

    @ViewBuilder
    private func content(_ part: SpotPart, _ frame: SheetPlacement.Frame) -> some View {
        switch part.control {
        case .text(let text, _, let placeholder, let isReadOnly):
            textArea(part, frame, text: text, placeholder: placeholder, isReadOnly: isReadOnly)
                .overlay(alignment: .topTrailing) { cornerMark(part, frame) }
        case .slider(let level, let low, let high):
            slider(part, level: level, low: low, high: high)
        case .swatches(let colors, let value) where colors.count > 1:
            HStack(spacing: Self.lineGap) {
                mark(part)
                swatches(part, colors: colors, value: value)
            }
        case .list(let items, let value):
            list(part, items: items, value: value)
                .overlay(alignment: .topTrailing) { cornerMark(part, frame) }
        case .metric(let number):
            metric(part, number: number)
        case .chart(let points):
            chart(points)
        case .image(let path):
            image(path)
        case .progress(let level):
            progress(part, level: level)
        default:
            if part.press == .line {
                lineButton(part, frame)
            } else {
                labelled(part, frame).modifier(TileLook(isOn: part.look == .tile, isSelected: isSelected(part)))
            }
        }
    }

    /// The running work of a part, in the slot of its symbol. The square of a part that takes a press says that it stops.
    @ViewBuilder
    private func mark(_ part: SpotPart) -> some View {
        if let call = work(part) {
            SpotWorkMark(call: call, side: SpotTokens.workMark, stops: part.isPressable)
        }
    }

    /// The running work of a part that fills its cell, in the corner of that cell.
    private func cornerMark(_ part: SpotPart, _ frame: SheetPlacement.Frame) -> some View {
        mark(part).padding(frame.isInCard ? 0 : SpotTokens.controlPadding)
    }

    /// A line with a label, a value, a round button and a switch or a menu.
    private func labelled(_ part: SpotPart, _ frame: SheetPlacement.Frame) -> some View {
        HStack(spacing: frame.rect.width < Self.narrowCell ? Self.narrowGap : Self.lineGap) {
            if !hasRoundMark(part), work(part) != nil {
                mark(part)
            } else if let symbol = part.symbol {
                Image(systemName: symbol).modifier(SpotSecondaryText())
            }
            if let title = part.title {
                Text(title)
                    .font(part.isSection || part.look == .section ? SpotType.title : SpotType.body)
                    .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            if part.title != nil || part.detail != nil {
                Spacer(minLength: 0)
            }
            if let detail = part.detail {
                Text(detail)
                    .font(SpotType.detail)
                    .modifier(SpotSecondaryText())
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            if case .symbol(let symbol) = part.press {
                SpotRoundButton(
                    symbol: symbol,
                    label: part.title ?? part.id.capitalized,
                    work: work(part),
                    size: frame.roundSize,
                    look: part.look == .strong ? .strong : frame.isOnTop ? .floating : part.look == .bare ? .bare : .plain
                ) { onPress(part) }
            }
            control(part, frame)
        }
    }

    /// Whether a part shows its running work on its round button.
    private func hasRoundMark(_ part: SpotPart) -> Bool {
        if case .symbol = part.press { return true }
        return false
    }

    /// What a button says: its own words, or the running work of its part and the word that a press stops it.
    @ViewBuilder
    private func pressLabel(_ part: SpotPart, words: String, font: Font) -> some View {
        if let call = work(part) {
            HStack(spacing: SpotTokens.placeGap / 2) {
                SpotWorkMark(call: call, side: SpotTokens.workMark, isOnWhite: part.look == .strong)
                Text("Stop").font(font).lineLimit(1)
            }
        } else {
            Text(words).font(font).lineLimit(1)
        }
    }

    /// A line that is a button. It looks like one by default, and `look` changes how.
    @ViewBuilder
    private func lineButton(_ part: SpotPart, _ frame: SheetPlacement.Frame) -> some View {
        Button { onPress(part) } label: {
            switch part.look {
            case .key:
                Group {
                    if let call = work(part) {
                        SpotWorkMark(call: call, side: SpotTokens.workMark, stops: true)
                    } else {
                        Text(part.title ?? part.id).font(Self.keyFont)
                    }
                }
                .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(SpotTokens.selectedFill), in: shape)
                    .contentShape(shape)
            case .chip:
                pressLabel(part, words: part.title ?? part.id, font: SpotType.action)
                    .foregroundStyle(.white)
                    .padding(.horizontal, SpotTokens.padding)
                    .padding(.vertical, 5)
                    .fixedSize()
                    .background(frame.isOnTop ? AnyShapeStyle(Self.topFill) : AnyShapeStyle(Color.white.opacity(SpotTokens.selectedFill)), in: Capsule())
                    .background(frame.isOnTop ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(Color.clear), in: Capsule())
                    .contentShape(Capsule())
            case .bare:
                HStack {
                    labelled(part, frame)
                    if part.detail == nil, let key = part.key {
                        Text(key.label).font(SpotType.detail).modifier(SpotSecondaryText())
                    }
                }
                .contentShape(Rectangle())
            case .strong where frame.isOnTop:
                pressLabel(part, words: part.title ?? part.id.capitalized, font: SpotType.action)
                    .foregroundStyle(.black)
                    .padding(.horizontal, SpotTokens.padding)
                    .padding(.vertical, 5)
                    .fixedSize()
                    .background(Color.white, in: Capsule())
                    .contentShape(Capsule())
            case .strong:
                centeredLine(part, text: .black, fill: Color.white)
            case .tile:
                labelled(part, frame)
                    .modifier(TileLook(isOn: true, isSelected: isSelected(part)))
                    .contentShape(shape)
            default:
                centeredLine(part, text: .white, fill: Color.white.opacity(SpotTokens.selectedFill))
            }
        }
        .buttonStyle(.plain)
    }

    private func centeredLine(_ part: SpotPart, text: Color, fill: Color) -> some View {
        pressLabel(part, words: part.title ?? part.id.capitalized, font: SpotType.body.weight(.medium))
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(fill, in: shape)
            .contentShape(shape)
    }

    @ViewBuilder
    private func control(_ part: SpotPart, _ frame: SheetPlacement.Frame) -> some View {
        switch part.control {
        case .toggle(let on):
            Toggle(part.title ?? part.id, isOn: Binding(get: { on }, set: { onSet(part, $0 ? "true" : "false") }))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        case .menu(let options, let value):
            menu(part, frame, options: options, value: value)
        case .shortcut(let text):
            shortcut(part, text: text)
        case .swatches(let colors, let value):
            if let color = colors.first {
                swatch(part, color: color, isChosen: color == value, size: Self.smallSwatch)
            }
        default:
            EmptyView()
        }
    }

    private func menu(_ part: SpotPart, _ frame: SheetPlacement.Frame, options: [SpotPart.Option], value: String?) -> some View {
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
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .modifier(SpotSecondaryText())
            }
            .padding(.horizontal, frame.isOnTop ? 10 : 0)
            .padding(.vertical, frame.isOnTop ? 5 : 0)
            .background(frame.isOnTop ? AnyShapeStyle(Self.topFill) : AnyShapeStyle(Color.clear), in: Capsule())
            .background(frame.isOnTop ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(Color.clear), in: Capsule())
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
    }

    /// The key of a part. A click asks for the next key that the person presses.
    private func shortcut(_ part: SpotPart, text: String) -> some View {
        Button { onRecord(part) } label: {
            Text(recordingPart == part.id ? "Press keys" : Shortcut(text: text)?.label ?? text)
                .font(SpotType.action)
                .foregroundStyle(.white)
                .padding(.horizontal, SpotTokens.padding)
                .padding(.vertical, 5)
                .fixedSize()
                .background(Color.white.opacity(SpotTokens.selectedFill), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func slider(_ part: SpotPart, level: Double, low: Double, high: Double) -> some View {
        HStack(spacing: Self.lineGap) {
            if let title = part.title {
                Text(title)
                    .font(SpotType.body)
                    .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                    .lineLimit(1)
            }
            if work(part) != nil {
                mark(part)
            } else if let symbol = part.symbol {
                Image(systemName: symbol)
                    .foregroundStyle(.white)
            }
            Slider(value: Binding(get: { level }, set: { onSet(part, String(Int($0.rounded()))) }), in: low...max(high, low + 1))
                .controlSize(.small)
                .tint(.white)
                .labelsHidden()
        }
    }

    /// A row of colours that reaches both edges of its cell.
    private func swatches(_ part: SpotPart, colors: [String], value: String?) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                if index > 0 { Spacer(minLength: 0) }
                swatch(part, color: color, isChosen: color == value, size: Self.swatchSize)
            }
        }
    }

    private func swatch(_ part: SpotPart, color: String, isChosen: Bool, size: CGFloat) -> some View {
        Button { onSet(part, color) } label: {
            Circle()
                .fill(Self.color(color))
                .frame(width: size, height: size)
                .overlay {
                    if isChosen { Circle().strokeBorder(.white, lineWidth: 2) }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color)
    }

    private static func color(_ text: String) -> Color {
        let value = Int(text.dropFirst(), radix: 16) ?? 0
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// Rows to choose from, one under the other, which scroll when they do not fit.
    private func list(_ part: SpotPart, items: [SpotPart.Option], value: String?) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpotTokens.listRowGap) {
                ForEach(items, id: \.id) { item in
                    Button { onSet(part, item.id) } label: {
                        Text(item.title)
                            .font(SpotType.body)
                            .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, SpotTokens.controlPadding)
                            .frame(height: SheetPlacement.rowHeight)
                            .background(Color.white.opacity(item.id == value ? SpotTokens.selectedFill : 0), in: shape)
                            .contentShape(shape)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func metric(_ part: SpotPart, number: String) -> some View {
        VStack(alignment: part.look == .bare ? .trailing : .leading, spacing: SpotType.lineGap) {
            Text(number)
                .font(Self.metricFont)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let title = part.title {
                Text(title)
                    .font(SpotType.detail)
                    .modifier(SpotSecondaryText())
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: part.look == .bare ? .trailing : .leading)
        .padding(.horizontal, part.look == .bare ? 0 : SpotTokens.padding)
        .background(Color.white.opacity(part.look == .bare ? 0 : SpotTokens.fill), in: shape)
    }

    private func chart(_ points: [Double]) -> some View {
        let top = max(points.max() ?? 1, 1)
        return GeometryReader { room in
            HStack(alignment: .bottom, spacing: Self.barGap) {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.7))
                        .frame(height: room.size.height * max(point, 0) / top)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .padding(SpotTokens.padding)
        .background(Color.white.opacity(SpotTokens.fill), in: shape)
    }

    /// The picture at a file path. A file it cannot read shows an empty tile.
    private func image(_ path: String) -> some View {
        Group {
            if let picture = NSImage(contentsOfFile: path) {
                Image(nsImage: picture).resizable().scaledToFill()
            } else {
                Color.white.opacity(SpotTokens.fill)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(shape)
    }

    private func progress(_ part: SpotPart, level: Double) -> some View {
        VStack(spacing: Self.lineGap) {
            HStack {
                Text(part.title ?? "")
                    .font(SpotType.body)
                    .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                    .lineLimit(1)
                Spacer(minLength: Self.lineGap)
                if let detail = part.detail {
                    Text(detail).font(SpotType.detail).modifier(SpotSecondaryText()).lineLimit(1)
                }
            }
            ProgressView(value: min(max(level, 0), 100), total: 100)
                .progressViewStyle(.linear)
                .tint(.white)
                .controlSize(.small)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func textArea(_ part: SpotPart, _ frame: SheetPlacement.Frame, text: String, placeholder: String?, isReadOnly: Bool) -> some View {
        let inset = frame.isInCard ? 0 : SpotTokens.padding
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
        .padding(.horizontal, inset)
        .padding(.top, inset + frame.clearTop)
        .padding(.bottom, inset + frame.clearBottom)
        .background(Color.white.opacity(frame.isInCard ? 0 : SpotTokens.fill), in: shape)
    }
}

/// The filled row of `look=tile`.
private struct TileLook: ViewModifier {
    let isOn: Bool
    let isSelected: Bool

    func body(content: Content) -> some View {
        if isOn {
            content
                .padding(.horizontal, SpotTokens.padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(isSelected ? SpotTokens.selectedFill : SpotTokens.fill), in: RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous))
        } else {
            content
        }
    }
}
