import AppKit
import OpenspotCore
import SwiftUI

/// The parts that a script prints, drawn with system controls where `SheetPlacement` puts them. It draws what it gets,
/// and reports each change.
struct SheetPartsView: View {
    let panel: SheetParts
    var work: (SpotPart) -> ScriptCall? = { _ in nil }
    let onSet: (SpotPart, String) -> Void
    let onPress: (SpotPart) -> Void
    var recordingPart: String?
    var onRecord: (SpotPart) -> Void = { _ in }
    var list = ItemList()
    var onRun: (SpotItem) -> Void = { _ in }
    var onDragOut: ([SpotItem]) -> Void = { _ in }
    var selection: (() -> Int)?
    /// Reads the id of the selected part where it is called. Nil reads it from the parts.
    var selectedPart: (() -> String?)?
    var nudge: () -> SheetParts.Nudge = { SheetParts.Nudge.rest }
    /// The last press of return that asks a menu to open.
    var menuOpening: () -> SheetParts.MenuOpening? = { nil }
    /// Takes a click into a field, which gives that part the focus.
    var onFocus: (SpotPart) -> Void = { _ in }
    /// The source of the spot's own view, which a `view` component draws at the size of its area (protocol: Views).
    var viewSource: String?
    var views = SpotViews.shared
    @FocusState private var focus: String?

    private static let swatchSize: CGFloat = 22
    private static let smallSwatch: CGFloat = 16
    private static let lineGap: CGFloat = 8
    private static let barGap: CGFloat = 3
    private static let narrowCell: CGFloat = 80
    private static let narrowGap: CGFloat = 2
    private static let markValueWidth: CGFloat = 36
    private static let symbolWidth: CGFloat = 22
    private static let metricFont = Font.system(size: 24, weight: .semibold, design: .rounded).monospacedDigit()

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
    }

    var body: some View {
        let sheet = panel.placement
        Group {
            if sheet.overflows {
                ScrollView(showsIndicators: false) { canvas(sheet) }
                    .modifier(SpotArrowScroll(nudge: nudge))
            } else {
                canvas(sheet)
            }
        }
        .onAppear(perform: focusSelectedField)
        .modifier(FocusOnShow(focus: focusSelectedField))
        .modifier(FocusOnSelect(selectedID: selectedID, focus: focusSelectedField))
        .onChange(of: focus) { _, id in
            if let part = panel.parts.first(where: { $0.id == id }) { onFocus(part) }
        }
    }

    private func canvas(_ sheet: SheetPlacement) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(sheet.lines.enumerated()), id: \.offset) { _, line in
                Rectangle()
                    .fill(SpotTheme.ink.opacity(SpotTheme.fill))
                    .frame(width: line.width, height: line.height)
                    .offset(x: line.minX, y: line.minY)
            }
            if let area = sheet.repeatFrame {
                SpotRowsView(list: list, onRun: onRun, selection: selection, onDragOut: onDragOut)
                    .frame(width: area.width, height: area.height)
                    .offset(x: area.minX, y: area.minY)
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
        drawn(part, frame)
            .frame(
                maxWidth: frame.horizontal == .fill ? .infinity : nil,
                maxHeight: frame.vertical == .fill ? .infinity : nil,
                alignment: .leading
            )
            .frame(width: frame.rect.width, height: frame.rect.height, alignment: Self.alignment(frame))
            .background {
                if part.isFocusable {
                    Color.clear.modifier(PartRing(id: part.id, selectedID: selectedID, hasBox: hasBox(part, frame), shape: shape))
                }
            }
            .offset(x: frame.rect.minX, y: frame.rect.minY)
            .zIndex(frame.isOnTop ? 1 : 0)
    }

    private var selectedID: () -> String? {
        selectedPart ?? { [panel] in panel.selectedPart?.id }
    }

    /// Whether a part fills its whole cell with a box of its own, as a button, a tile or a field does.
    private func hasBox(_ part: SpotPart, _ frame: SheetPlacement.Frame) -> Bool {
        if part.isEditable || part.look == .tile { return true }
        guard part.press == .line else { return false }
        return switch part.look {
        case .chip, .bare: false
        case .strong: !frame.isOnTop
        default: true
        }
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

    /// Gives the text focus to the field that has the focus of the sheet, and takes it from a field that lost it.
    private func focusSelectedField() {
        guard !panel.showsRows else { return }
        let id = selectedID()
        DispatchQueue.main.async { focus = panel.parts.first { $0.id == id && $0.isEditable }?.id }
    }

    @ViewBuilder
    private func drawn(_ part: SpotPart, _ frame: SheetPlacement.Frame) -> some View {
        if part.kind == "view" {
            if let viewSource {
                SpotCustomView(source: viewSource, values: part.values, card: .square, room: frame.rect.size, views: views) { onSet(part, $0) }
                    .equatable()
            }
        } else {
            content(part, frame)
        }
    }

    @ViewBuilder
    private func content(_ part: SpotPart, _ frame: SheetPlacement.Frame) -> some View {
        switch part.control {
        case .text(let text, let placeholder, let isReadOnly):
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
                labelled(part, frame).modifier(TileLook(isOn: part.look == .tile))
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
        mark(part).padding(SpotTokens.controlPadding)
    }

    /// A line with a label, a value, a round button and a switch or a menu, or a text over two lines with its detail under
    /// its title.
    @ViewBuilder
    private func labelled(_ part: SpotPart, _ frame: SheetPlacement.Frame) -> some View {
        if frame.hasDetailUnderTitle, part.control == .none, part.press == .none, part.mark == nil, let title = part.title, let detail = part.detail {
            stacked(part, title: title, detail: detail)
        } else {
            line(part, frame)
        }
    }

    /// A title with its detail under it, which wraps to fill the height of its place.
    private func stacked(_ part: SpotPart, title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Self.lineGap) {
            if let symbol = part.symbol {
                Image(systemName: symbol)
                    .modifier(SpotSecondaryText())
                    .frame(width: Self.symbolWidth)
            }
            VStack(alignment: .leading, spacing: SpotType.lineGap) {
                Text(title).font(SpotType.body).foregroundStyle(SpotTheme.ink).lineLimit(1)
                Group {
                    if let colour = SpotToneWords.colour(of: part.textTone) {
                        Text(detail).foregroundStyle(colour)
                    } else {
                        Text(detail).modifier(SpotSecondaryText())
                    }
                }
                .font(SpotType.detail)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .modifier(SpotColorBar(color: part.color))
    }

    /// A line with a label, a value, a round button and a switch or a menu.
    private func line(_ part: SpotPart, _ frame: SheetPlacement.Frame) -> some View {
        HStack(spacing: frame.rect.width < Self.narrowCell ? Self.narrowGap : Self.lineGap) {
            if !hasRoundMark(part), work(part) != nil {
                mark(part)
            } else if let symbol = part.symbol {
                Image(systemName: symbol)
                    .modifier(SpotSecondaryText())
                    .frame(width: Self.symbolWidth)
            }
            else if panel.keepsIconColumn(part) {
                Color.clear.frame(width: Self.symbolWidth, height: 0)
            }
            if let title = part.title {
                Text(title)
                    .font(part.isSection ? SpotType.title : SpotType.body)
                    .foregroundStyle(part.detail == nil ? SpotToneWords.colour(of: part.textTone) ?? SpotTheme.ink : SpotTheme.ink)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            if part.title != nil || part.detail != nil {
                Spacer(minLength: 0)
            }
            if let mark = part.mark {
                SpotLineMark(value: mark, words: part.ringWords)
            }
            if let detail = part.detail, part.ringWords == nil {
                SpotToneWords(text: detail, tone: part.textTone)
                    .frame(minWidth: part.mark == nil ? nil : Self.markValueWidth, alignment: .trailing)
                    .layoutPriority(2)
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
        .modifier(SpotColorBar(color: part.color))
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
                SpotWorkMark(call: call, side: SpotTokens.workMark, isOnSolid: part.look == .strong)
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
            case .chip:
                pressLabel(part, words: part.title ?? part.id, font: SpotType.action)
                    .foregroundStyle(SpotTheme.ink)
                    .padding(.horizontal, SpotTokens.padding)
                    .padding(.vertical, 5)
                    .fixedSize()
                    .background(SpotTheme.ink.opacity(frame.isOnTop ? SpotTheme.control : SpotTheme.selectedFill), in: Capsule())
                    .background { if frame.isOnTop { SpotFloatGlass(shape: Capsule()) } }
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
                    .foregroundStyle(SpotTheme.onSolid)
                    .padding(.horizontal, SpotTokens.padding)
                    .padding(.vertical, 5)
                    .fixedSize()
                    .background(SpotTheme.solid, in: Capsule())
                    .contentShape(Capsule())
            case .strong:
                centeredLine(part, text: SpotTheme.onSolid, fill: SpotTheme.solid)
            case .tile:
                labelled(part, frame)
                    .modifier(TileLook(isOn: true))
                    .contentShape(shape)
            default:
                centeredLine(part, text: SpotTheme.ink, fill: SpotTheme.ink.opacity(SpotTheme.selectedFill))
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
        case .toggle(let on) where part.look == .tick:
            SpotTick(isOn: on, words: EmptyView()) { onSet(part, $0 ? "true" : "false") }
                .fixedSize()
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
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .modifier(SpotSecondaryText())
            }
            .padding(.horizontal, frame.isOnTop ? 10 : 0)
            .padding(.vertical, frame.isOnTop ? 5 : 0)
            .background(SpotTheme.ink.opacity(frame.isOnTop ? SpotTheme.control : 0), in: Capsule())
            .background { if frame.isOnTop { SpotFloatGlass(shape: Capsule()) } }
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
        .background {
            GeometryReader { room in
                Color.clear.onChange(of: menuOpening()) { _, opening in
                    guard opening?.part == part.id else { return }
                    let rect = room.frame(in: .global)
                    DispatchQueue.main.async {
                        SpotChoiceMenu.popUp(options: options, value: value, under: rect) { onSet(part, $0) }
                    }
                }
            }
        }
    }

    /// The key of a part. A click asks for the next key that the person presses.
    private func shortcut(_ part: SpotPart, text: String) -> some View {
        Button { onRecord(part) } label: {
            SpotKeyLabel(text: text, isRecording: recordingPart == part.id)
        }
        .buttonStyle(.plain)
    }

    private func slider(_ part: SpotPart, level: Double, low: Double, high: Double) -> some View {
        HStack(spacing: Self.lineGap) {
            if let title = part.title {
                Text(title)
                    .font(SpotType.body)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
            }
            if work(part) != nil {
                mark(part)
            } else if let symbol = part.symbol {
                Image(systemName: symbol)
                    .foregroundStyle(SpotTheme.ink)
            }
            SpotSlotSlider(level: level, range: low...max(high, low + 1)) { onSet(part, String(Int($0.rounded()))) }
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
                .fill(SpotColorBar.color(color))
                .frame(width: size, height: size)
                .overlay {
                    if isChosen { Circle().strokeBorder(SpotTheme.ink, lineWidth: 2) }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color)
    }

    /// Rows to choose from, one under the other, which scroll when they do not fit.
    private func list(_ part: SpotPart, items: [SpotPart.Option], value: String?) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpotTokens.listRowGap) {
                ForEach(items, id: \.id) { item in
                    Button { onSet(part, item.id) } label: {
                        Text(item.title)
                            .font(SpotType.body)
                            .foregroundStyle(SpotTheme.ink)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, SpotTokens.controlPadding)
                            .frame(height: SheetPlacement.rowHeight)
                            .background(SpotTheme.ink.opacity(item.id == value ? SpotTheme.selectedFill : 0), in: shape)
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
                .foregroundStyle(SpotTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let title = part.title {
                Text(title)
                    .font(SpotType.detail)
                    .modifier(SpotSecondaryText())
                    .lineLimit(1)
            }
        }
        .modifier(SpotColorBar(color: part.color))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: part.look == .bare ? .trailing : .leading)
        .padding(.horizontal, part.look == .bare ? 0 : SpotTokens.padding)
        .background(SpotTheme.ink.opacity(part.look == .bare ? 0 : SpotTheme.fill), in: shape)
    }

    private func chart(_ points: [Double]) -> some View {
        SpotBars(points: points, gap: Self.barGap, radius: 2)
            .padding(SpotTokens.padding)
            .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
    }

    private func image(_ path: String) -> some View {
        SheetPicture(arrived: SpotPictureStore.Key(path: path, changed: panel.pictureTimes[path]))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(shape)
    }

    private func progress(_ part: SpotPart, level: Double) -> some View {
        VStack(spacing: Self.lineGap) {
            HStack {
                Text(part.title ?? "")
                    .font(SpotType.body)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                Spacer(minLength: Self.lineGap)
                if let detail = part.detail {
                    Text(detail).font(SpotType.detail).modifier(SpotSecondaryText()).lineLimit(1)
                }
            }
            ProgressView(value: min(max(level, 0), 100), total: 100)
                .progressViewStyle(.linear)
                .tint(SpotTheme.ink)
                .controlSize(.small)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func textArea(_ part: SpotPart, _ frame: SheetPlacement.Frame, text: String, placeholder: String?, isReadOnly: Bool) -> some View {
        let inset = SpotTokens.padding
        let space = EdgeInsets(top: inset + frame.clearTop, leading: inset, bottom: inset + frame.clearBottom, trailing: inset)
        ZStack(alignment: .topLeading) {
            if isReadOnly {
                ScrollView(showsIndicators: false) {
                    Text(text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(space)
                }
                .clipShape(RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous))
            } else {
                TextEditor(text: Binding(get: { text }, set: { onSet(part, $0) }))
                    .scrollContentBackground(.hidden)
                    .focused($focus, equals: part.id)
                    .padding(.horizontal, -SpotTokens.editorInset)
                    .padding(space)
            }
            if text.isEmpty, let placeholder {
                Text(placeholder)
                    .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
                    .allowsHitTesting(false)
                    .padding(space)
            }
        }
        .font(SpotType.body)
        .foregroundStyle(SpotTheme.ink)
        .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
    }
}

/// Gives the focus back once the panel has faded in. It alone reads whether the panel shows, so that a show reruns no part.
private struct FocusOnShow: ViewModifier {
    let focus: @MainActor @Sendable () -> Void
    @Environment(\.spotIsShown) private var isShown

    func body(content: Content) -> some View {
        content.onChange(of: isShown) { _, isShown in
            if isShown { DispatchQueue.main.asyncAfter(deadline: .now() + MotionTokens.fadeIn, execute: focus) }
        }
    }
}

/// The ring of the focused part: a few points outside its own box, with that box's corners, or around its line, with room
/// for its words at each side, when it has no box. It reads the focus itself, so a move of the focus redraws only rings.
private struct PartRing: ViewModifier {
    let id: String
    let selectedID: () -> String?
    let hasBox: Bool
    let shape: RoundedRectangle

    func body(content: Content) -> some View {
        let isSelected = selectedID() == id
        if hasBox {
            let gap = SpotTokens.focusGap
            let ring = RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding + gap, style: .continuous)
            content.modifier(SpotSelectionRing(isSelected: isSelected, shape: ring)).padding(-gap)
        } else {
            content.modifier(SpotSelectionRing(isSelected: isSelected, shape: shape)).padding(.horizontal, -SpotTokens.controlPadding)
        }
    }
}

/// Gives the focus to the field that the keyboard selects. It reads the selection itself, so a move redraws only this.
private struct FocusOnSelect: ViewModifier {
    let selectedID: () -> String?
    let focus: () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: selectedID()) { focus() }
    }
}

/// The filled row of `look=tile`.
private struct TileLook: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
        if isOn {
            content
                .padding(.horizontal, SpotTokens.padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SpotTheme.ink.opacity(SpotTheme.fill), in: RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous))
        } else {
            content
        }
    }
}

/// The picture at a file path, which fills its area and is cut at its edges. It shows an empty tile until it is read, and
/// stays empty for a file it cannot read. It starts from the time its parts read, and follows the file's later changes off
/// the main thread, so that a picture that a spot writes after its answer shows.
private struct SheetPicture: View {
    let arrived: SpotPictureStore.Key
    @State private var followed: (from: SpotPictureStore.Key, changed: Double?)?
    @State private var loaded: (key: SpotPictureStore.Key, image: CGImage)?

    private var key: SpotPictureStore.Key {
        followed.flatMap { $0.from == arrived ? SpotPictureStore.Key(path: arrived.path, changed: $0.changed) : nil } ?? arrived
    }

    var body: some View {
        let key = key
        Color.clear
            .overlay {
                if let image = SpotPictureStore.shared.cached(key) ?? (loaded?.key == key ? loaded?.image : nil) {
                    Image(decorative: image, scale: SpotPictureStore.scale).resizable().scaledToFill()
                } else {
                    SpotTheme.ink.opacity(SpotTheme.fill)
                }
            }
            .task(id: key) {
                if let image = await SpotPictureStore.shared.image(key) { loaded = (key, image) }
            }
            .task(id: arrived) {
                for await changed in PictureFile(path: arrived.path).changes { followed = (arrived, changed) }
            }
    }
}
