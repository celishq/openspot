import AppKit
import OpenspotCore
import SwiftUI

struct SheetPartsView: View {
    @Environment(\.spotSurfaceEdge) private var surface
    let panel: SheetParts
    var act: (SpotPart) -> ScriptCall? = { _ in nil }
    let onSet: (SpotPart, String) -> Void
    let onPress: (SpotPart) -> Void
    var recordingPart: String?
    var onRecord: (SpotPart) -> Void = { _ in }
    var keys: KeyRecording?
    var list = ItemList()
    var onRun: (SpotItem) -> Void = { _ in }
    var onDragOut: ([SpotItem]) -> Void = { _ in }
    var selection: (() -> Int)?
    var selectedPart: (() -> String?)?
    var nudge: () -> SheetParts.Nudge = { SheetParts.Nudge.rest }
    var menuOpening: () -> SheetParts.MenuOpening? = { nil }
    var onFocus: (SpotPart) -> Void = { _ in }
    var viewSource: String?
    var viewDate: Date?
    var views = SpotViews.shared
    @FocusState private var focus: String?
    @Environment(\.spotIsHeld) private var isHeld

    private var shape: SpotRoundShape {
        SpotRoundShape(surface.inner())
    }

    var body: some View {
        let sheet = panel.placement
        Group {
            if sheet.overflows {
                ScrollView(showsIndicators: false) { canvas(sheet) }
                    .modifier(SpotArrowScroll(nudge: nudge, searches: list.landedSearches))
            } else {
                canvas(sheet)
            }
        }
        .onAppear(perform: focusSelectedField)
        .modifier(FocusOnShow(focus: focusSelectedField))
        .modifier(FocusOnSelect(selectedID: selectedID, focus: focusSelectedField))
        .onChange(of: focus) { _, id in
            if !isHeld, let part = panel.parts.first(where: { $0.id == id }) { onFocus(part) }
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
                SpotItemsView(list: list, onRun: onRun, selection: selection, onDragOut: onDragOut, room: area.height)
                    .frame(width: area.width, height: area.height)
                    .mask(alignment: .top) { Rectangle().frame(height: area.height + SpotTokens.padding) }
                    .offset(x: area.minX, y: area.minY)
            }
            ForEach(panel.parts) { part in
                if let frame = sheet.frames[part.id] {
                    placed(part, frame)
                }
            }
        }
        .frame(width: SpotTokens.partsWidth, height: sheet.height, alignment: .topLeading)
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

    private var selectedRun: () -> String? {
        { [list, selection] in list.run(at: (selection ?? { list.selected })()) }
    }

    private var selectedID: () -> String? {
        selectedPart ?? { [panel] in panel.selectedPart?.id }
    }

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

    private func focusSelectedField() {
        guard !isHeld, !panel.showsRows else { return }
        let id = selectedID()
        DispatchQueue.main.async { focus = panel.parts.first { $0.id == id && $0.isEditable }?.id }
    }

    @ViewBuilder
    private func drawn(_ part: SpotPart, _ frame: SheetPlacement.Frame) -> some View {
        if part.isOpen {
            if let viewSource {
                SpotSelectionScope(run: views.readsSelection(viewSource) ? selectedRun : { nil }) { run in
                    SpotCustomView(source: viewSource, values: part.values, items: part.items, card: .square, room: frame.rect.size, answers: panel.answered, selection: run, date: viewDate, views: views) { onSet(part, $0) }
                        .equatable()
                }
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
            HStack(spacing: SpotTokens.partLineGap) {
                mark(part)
                swatches(part, colors: colors, value: value)
            }
        case .list(let items, let value):
            list(part, items: items, value: value)
                .overlay(alignment: .topTrailing) { cornerMark(part, frame) }
        case .number:
            number(part, frame)
        case .image(let path):
            image(path)
        case .shortcut(let text):
            shortcut(part, text: text)
        default:
            if part.press == .line {
                lineButton(part, frame)
            } else {
                labelled(part, frame).modifier(TileLook(isOn: part.look == .tile))
            }
        }
    }

    @ViewBuilder
    private func mark(_ part: SpotPart) -> some View {
        if let call = act(part) {
            SpotWorkMark(call: call, side: SpotTokens.workMark, stops: part.isPressable)
        }
    }

    private func cornerMark(_ part: SpotPart, _ frame: SheetPlacement.Frame) -> some View {
        mark(part).padding(SpotTokens.controlPadding)
    }

    @ViewBuilder
    private func labelled(_ part: SpotPart, _ frame: SheetPlacement.Frame) -> some View {
        if frame.hasDetailUnderTitle, part.control == .none, part.press == .none, part.mark == nil, let title = part.title, let detail = part.detail {
            stacked(part, title: title, detail: detail)
        } else {
            line(part, frame)
        }
    }

    private func stacked(_ part: SpotPart, title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SpotTokens.partLineGap) {
            if let symbol = part.symbol {
                Image(systemName: symbol)
                    .modifier(SpotSecondaryText())
                    .frame(width: SpotTokens.partSymbolWidth)
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

    private func line(_ part: SpotPart, _ frame: SheetPlacement.Frame) -> some View {
        HStack(spacing: frame.rect.width < SpotTokens.narrowCell ? SpotTokens.narrowGap : SpotTokens.partLineGap) {
            if !hasRoundMark(part), act(part) != nil {
                mark(part)
            } else if let symbol = part.symbol {
                Image(systemName: symbol)
                    .modifier(SpotSecondaryText())
                    .frame(width: SpotTokens.partSymbolWidth)
            }
            else if panel.keepsIconColumn(part) {
                Color.clear.frame(width: SpotTokens.partSymbolWidth, height: 0)
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
                    .frame(minWidth: part.mark == nil ? nil : SpotTokens.markValueWidth, alignment: .trailing)
                    .layoutPriority(2)
            }
            if case .symbol(let symbol) = part.press {
                SpotRoundButton(
                    symbol: symbol,
                    label: part.title ?? part.id.capitalized,
                    act: act(part),
                    size: frame.roundSize,
                    look: part.look == .strong ? .strong : frame.isOnTop ? .floating : part.look == .bare ? .bare : .plain
                ) { onPress(part) }
            }
            control(part, frame)
        }
        .modifier(SpotColorBar(color: part.color))
    }

    private func hasRoundMark(_ part: SpotPart) -> Bool {
        if case .symbol = part.press { return true }
        return false
    }

    @ViewBuilder
    private func pressLabel(_ part: SpotPart, words: String, font: Font) -> some View {
        if let call = act(part) {
            HStack(spacing: SpotTokens.placeGap / 2) {
                SpotWorkMark(call: call, side: SpotTokens.workMark)
                Text("Stop").font(font).lineLimit(1)
            }
        } else {
            Text(words).font(font).lineLimit(1)
        }
    }

    @ViewBuilder
    private func lineButton(_ part: SpotPart, _ frame: SheetPlacement.Frame) -> some View {
        Button { onPress(part) } label: {
            switch part.look {
            case .chip:
                pressLabel(part, words: part.title ?? part.id, font: SpotType.action)
                    .padding(.horizontal, SpotTokens.padding)
                    .padding(.vertical, SpotTokens.chipPaddingY)
                    .fixedSize()
                    .spotFill(isActive: act(part) != nil, otherwise: SpotTheme.ink.opacity(frame.isOnTop ? SpotTheme.control : SpotTheme.selectedFill), in: Capsule())
                    .background { if frame.isOnTop { SpotFloatGlass(shape: Capsule()) } }
                    .spotHover(isOnSolid: act(part) != nil, in: Capsule())
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
                    .padding(.horizontal, SpotTokens.padding)
                    .padding(.vertical, SpotTokens.chipPaddingY)
                    .fixedSize()
                    .spotFill(isActive: true, in: Capsule())
                    .spotHover(isOnSolid: true, in: Capsule())
                    .contentShape(Capsule())
            case .strong:
                centeredLine(part, isActive: true)
            case .tile:
                labelled(part, frame)
                    .modifier(TileLook(isOn: true))
                    .spotHover(in: shape)
                    .contentShape(shape)
            default:
                centeredLine(part, isActive: act(part) != nil)
            }
        }
        .buttonStyle(.plain)
    }

    private func centeredLine(_ part: SpotPart, isActive: Bool) -> some View {
        pressLabel(part, words: part.title ?? part.id.capitalized, font: SpotType.body.weight(.medium))
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                if let key = part.key { SpotButtonKey(label: key.label) }
            }
            .padding(.horizontal, SpotTokens.padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .spotFill(isActive: isActive, otherwise: SpotTheme.ink.opacity(SpotTheme.selectedFill), in: shape)
            .spotHover(isOnSolid: isActive, in: shape)
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
                .tint(SpotTheme.accent)
        case .menu(let options, let value):
            menu(part, frame, options: options, value: value)
        case .swatches(let colors, let value):
            if let color = colors.first {
                swatch(part, color: color, isChosen: color == value, size: SpotTokens.smallSwatch)
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
            HStack(spacing: SpotTokens.choiceChevronGap) {
                Text(options.first { $0.id == value }?.title ?? options.first?.title ?? "")
                    .font(SpotType.detail)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(SpotType.mark)
                    .modifier(SpotSecondaryText())
            }
            .padding(.horizontal, frame.isOnTop ? SpotTokens.choicePaddingX : 0)
            .padding(.vertical, frame.isOnTop ? SpotTokens.chipPaddingY : 0)
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

    private func shortcut(_ part: SpotPart, text: String) -> some View {
        Button { onRecord(part) } label: {
            LiveKeycaps(value: text, isRecording: recordingPart == part.id, keys: keys)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SpotTheme.well, in: shape)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func slider(_ part: SpotPart, level: Double, low: Double, high: Double) -> some View {
        HStack(spacing: SpotTokens.partLineGap) {
            if let title = part.title {
                Text(title)
                    .font(SpotType.body)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
            }
            if act(part) != nil {
                mark(part)
            } else if let symbol = part.symbol {
                Image(systemName: symbol)
                    .foregroundStyle(SpotTheme.ink)
            }
            SpotSlider(level: level, range: low...max(high, low + 1)) { onSet(part, String(Int($0.rounded()))) }
        }
    }

    private func swatches(_ part: SpotPart, colors: [String], value: String?) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                if index > 0 { Spacer(minLength: 0) }
                swatch(part, color: color, isChosen: color == value, size: SpotTokens.swatchSize)
            }
        }
    }

    private func swatch(_ part: SpotPart, color: String, isChosen: Bool, size: CGFloat) -> some View {
        Button { onSet(part, color) } label: {
            Circle()
                .fill(SpotColorBar.color(color))
                .frame(width: size, height: size)
                .overlay {
                    if isChosen { Circle().strokeBorder(SpotTheme.ink, lineWidth: SpotTokens.ring) }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color)
    }

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
                            .frame(height: SpotTokens.listRow)
                            .background(SpotTheme.ink.opacity(item.id == value ? SpotTheme.selectedFill : 0), in: shape)
                            .contentShape(shape)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func number(_ part: SpotPart, _ frame: SheetPlacement.Frame) -> some View {
        let look = part.numberLook(inSheet: frame.rect.size) ?? .stat
        let inset = part.look == .bare ? 0 : look == .ring ? SpotTokens.partGap : SpotTokens.padding
        return SpotNumberView(part: part, look: look, font: SpotType.number, leastScale: SpotType.leastValueScale, alignment: part.look == .bare ? .trailing : .leading, inset: inset)
            .frame(width: frame.rect.width, height: frame.rect.height)
            .background(SpotTheme.ink.opacity(part.look == .bare ? 0 : SpotTheme.fill), in: shape)
    }

    private func image(_ path: String) -> some View {
        SheetPicture(arrived: SpotPictureStore.Key(path: path, changed: panel.pictureTimes[path]))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(shape)
    }

    @ViewBuilder
    private func textArea(_ part: SpotPart, _ frame: SheetPlacement.Frame, text: String, placeholder: String?, isReadOnly: Bool) -> some View {
        let inset = SpotTokens.padding
        let line = max((frame.rect.height - SpotType.titleLine) / 2, 0)
        let space = frame.rect.height > SpotTokens.listRow
            ? EdgeInsets(top: inset + frame.clearTop, leading: inset, bottom: inset + frame.clearBottom, trailing: inset)
            : EdgeInsets(top: line, leading: inset, bottom: line, trailing: inset)
        ZStack(alignment: .topLeading) {
            if isReadOnly {
                ScrollView(showsIndicators: false) {
                    Text(text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(space)
                }
                .clipShape(SpotRoundShape(surface.inner()))
            } else {
                TextEditor(text: Binding(get: { text }, set: { onSet(part, $0) }))
                    .scrollContentBackground(.hidden)
                    .focused($focus, equals: part.id)
                    .padding(.horizontal, -SpotTokens.editorInset)
                    .padding(space)
            }
            if text.isEmpty, let placeholder {
                Text(placeholder)
                    .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
                    .allowsHitTesting(false)
                    .padding(space)
            }
        }
        .font(SpotType.body)
        .foregroundStyle(SpotTheme.ink)
        .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
    }
}

private struct LiveKeycaps: View {
    let value: String
    let isRecording: Bool
    let keys: KeyRecording?

    var body: some View {
        let live = isRecording ? keys : nil
        SpotKeycaps(value: value, held: live?.held ?? [], isRecording: isRecording, status: keys?.status, pressed: live?.pressed, isKeyDown: live?.isKeyDown == true)
    }
}

private struct FocusOnShow: ViewModifier {
    let focus: @MainActor @Sendable () -> Void
    @Environment(\.spotIsShown) private var isShown

    func body(content: Content) -> some View {
        content.onChange(of: isShown) { _, isShown in
            if isShown { DispatchQueue.main.asyncAfter(deadline: .now() + MotionTokens.fadeIn, execute: focus) }
        }
    }
}

private struct PartRing: ViewModifier {
    @Environment(\.spotSurfaceEdge) private var surface
    let id: String
    let selectedID: () -> String?
    let hasBox: Bool
    let shape: SpotRoundShape

    func body(content: Content) -> some View {
        let isSelected = selectedID() == id
        if hasBox {
            let gap = SpotTokens.focusGap
            let ring = SpotRoundShape(surface.inner(by: SpotTokens.padding - gap))
            content.modifier(SpotSelectionRing(isSelected: isSelected, shape: ring)).padding(-gap)
        } else {
            content.modifier(SpotSelectionRing(isSelected: isSelected, shape: shape)).padding(.horizontal, -SpotTokens.controlPadding)
        }
    }
}

private struct FocusOnSelect: ViewModifier {
    let selectedID: () -> String?
    let focus: () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: selectedID()) { focus() }
    }
}

private struct TileLook: ViewModifier {
    @Environment(\.spotSurfaceEdge) private var surface
    let isOn: Bool

    func body(content: Content) -> some View {
        if isOn {
            content
                .padding(.horizontal, SpotTokens.padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SpotTheme.ink.opacity(SpotTheme.fill), in: SpotRoundShape(surface.inner()))
        } else {
            content
        }
    }
}

private struct SheetPicture: View {
    let arrived: SpotPictureStore.Key
    @State private var followed: (from: SpotPictureStore.Key, changed: Double?)?
    @State private var loaded: (key: SpotPictureStore.Key, image: CGImage)?
    @Environment(\.spotIsHeld) private var isHeld

    private var key: SpotPictureStore.Key {
        followed.flatMap { $0.from == arrived ? SpotPictureStore.Key(path: arrived.path, changed: $0.changed) : nil } ?? arrived
    }

    var body: some View {
        let key = key
        Color.clear
            .overlay {
                if let image = SpotPictureStore.shared.cached(key) ?? (loaded?.key == key ? loaded?.image : nil) {
                    Image(decorative: image, scale: SpotTokens.pictureScale).resizable().scaledToFill()
                } else {
                    SpotTheme.ink.opacity(SpotTheme.fill)
                }
            }
            .task(id: key) {
                if !isHeld, let image = await SpotPictureStore.shared.image(key) { loaded = (key, image) }
            }
            .task(id: arrived) {
                guard !isHeld else { return }
                for await changed in PictureFile(path: arrived.path).changes { followed = (arrived, changed) }
            }
    }
}
