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
    @FocusState private var focus: String?
    @Environment(\.spotIsHeld) private var isHeld

    private var shape: SpotRoundShape {
        SpotRoundShape(surface.inner())
    }

    var body: some View {
        tree
        .onAppear(perform: focusSelectedField)
        .modifier(FocusOnShow(focus: focusSelectedField))
        .modifier(FocusOnSelect(selectedID: selectedID, focus: focusSelectedField))
        .onChange(of: focus) { _, id in
            if !isHeld, let part = panel.parts.first(where: { $0.id == id }) { onFocus(part) }
        }
    }

    private var send: (String, String) -> Void {
        let parts = panel.parts
        let onSet = onSet
        return { id, value in
            if let part = parts.first(where: { $0.id == id }) { onSet(part, value) }
        }
    }

    private var tree: some View {
        ScrollView(showsIndicators: false) {
            NodeRoom(height: panel.height) {
                NodeTree(tree: panel.tree, pictureTimes: panel.pictureTimes)
                    .environment(\.spotNodeParts, nodeParts)
                    .environment(\.spotNodeSend, send)
                    .environment(\.spotNodeSelection, selectedID)
                    .environment(\.spotNodeViewInput, NodeViewInput(items: panel.rows, answers: panel.answered, selection: selectedRun))
            }
            .padding(SpotTokens.padding)
        }
        .scrollBounceBehavior(.basedOnSize)
        .modifier(SpotArrowScroll(nudge: nudge, searches: list.landedSearches))
        .frame(width: SpotTokens.partsWidth + 2 * SpotTokens.padding, height: panel.height + 2 * SpotTokens.padding, alignment: .topLeading)
        .padding(-SpotTokens.padding)
    }

    private var nodeParts: NodeParts {
        NodeParts(
            part: { id, label, look, size in
                guard let part = panel.parts.first(where: { $0.id == id }) else { return AnyView(EmptyView()) }
                return AnyView(nodePart(part.drawn(as: look), label: label, size: size))
            },
            items: { room in
                AnyView(SpotItemsView(list: list, onRun: onRun, selection: selection, onDragOut: onDragOut, room: room))
            }
        )
    }

    @ViewBuilder
    private func nodePart(_ part: SpotPart, label: AnyView?, size: CGSize) -> some View {
        let height = size.height
        let frame = PartFrame(node: CGSize(width: SpotTokens.partsWidth, height: height), part: part)
        Group {
            if let label {
                Button { onPress(part) } label: {
                    label
                        .spotHover(in: shape)
                        .contentShape(shape)
                }
                .buttonStyle(.plain)
            } else if part.fillsHeight {
                GeometryReader { room in
                    content(part, PartFrame(node: room.size, part: part))
                }
                .frame(minHeight: height, idealHeight: height)
                .frame(idealWidth: size.width)
            } else {
                content(part, frame)
                    .frame(maxWidth: frame.horizontal == .fill ? .infinity : nil, minHeight: height, maxHeight: .infinity, alignment: Self.alignment(frame))
            }
        }
        .background {
            if part.isFocusable {
                Color.clear.modifier(PartRing(id: part.id, selectedID: selectedID, hasBox: label != nil || hasBox(part), shape: shape))
            }
        }
    }

    private var selectedRun: () -> String? {
        { [list, selection] in list.run(at: (selection ?? { list.selected })()) }
    }

    private var selectedID: () -> String? {
        selectedPart ?? { [panel] in panel.selectedPart?.id }
    }

    private func hasBox(_ part: SpotPart) -> Bool {
        if part.isEditable || part.look == .tile { return true }
        guard part.press == .line else { return false }
        return switch part.look {
        case .chip, .bare: false
        default: true
        }
    }

    private static func alignment(_ frame: PartFrame) -> Alignment {
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
    private func content(_ part: SpotPart, _ frame: PartFrame) -> some View {
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
        case .shortcut(let text):
            shortcut(part, text: text)
        default:
            if part.press == .line {
                lineButton(part, frame)
            } else {
                line(part, frame).modifier(TileLook(isOn: part.look == .tile))
            }
        }
    }

    @ViewBuilder
    private func mark(_ part: SpotPart) -> some View {
        if let call = act(part) {
            SpotWorkMark(call: call, side: SpotTokens.workMark, stops: part.isPressable)
        }
    }

    private func cornerMark(_ part: SpotPart, _ frame: PartFrame) -> some View {
        mark(part).padding(SpotTokens.controlPadding)
    }

    private func line(_ part: SpotPart, _ frame: PartFrame) -> some View {
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
                    .font(SpotType.body)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            if part.title != nil || part.detail != nil {
                Spacer(minLength: 0)
            }
            if let detail = part.detail {
                Text(detail).font(SpotType.detail).modifier(SpotSecondaryText()).lineLimit(1)
                    .layoutPriority(2)
            }
            if case .symbol(let symbol) = part.press {
                SpotRoundButton(
                    symbol: symbol,
                    label: part.title ?? part.id.capitalized,
                    act: act(part),
                    size: frame.roundSize,
                    look: part.look == .strong ? .strong : part.look == .bare ? .bare : .plain
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
    private func lineButton(_ part: SpotPart, _ frame: PartFrame) -> some View {
        Button { onPress(part) } label: {
            switch part.look {
            case .chip:
                pressLabel(part, words: part.title ?? part.id, font: SpotType.action)
                    .padding(.horizontal, SpotTokens.padding)
                    .padding(.vertical, SpotTokens.chipPaddingY)
                    .fixedSize()
                    .spotFill(isActive: act(part) != nil, otherwise: SpotTheme.ink.opacity(SpotTheme.selectedFill), in: Capsule())
                    .spotHover(isOnSolid: act(part) != nil, in: Capsule())
                    .contentShape(Capsule())
            case .bare:
                HStack {
                    line(part, frame)
                    if part.detail == nil, let key = part.key {
                        Text(key.label).font(SpotType.detail).modifier(SpotSecondaryText())
                    }
                }
                .contentShape(Rectangle())
            case .strong:
                centeredLine(part, isActive: true)
            case .tile:
                line(part, frame)
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
    private func control(_ part: SpotPart, _ frame: PartFrame) -> some View {
        switch part.control {
        case .toggle(let on) where part.isTick:
            SpotTick(isOn: on, words: EmptyView()) { onSet(part, $0 ? "true" : "false") }
                .fixedSize()
        case .toggle(let on):
            Toggle(part.title ?? part.id, isOn: Binding(get: { on }, set: { onSet(part, $0 ? "true" : "false") }))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .tint(SpotTheme.accent)
        case .menu(let options, let value):
            menu(part, options: options, value: value)
        case .swatches(let colors, let value):
            if let color = colors.first {
                swatch(part, color: color, isChosen: color == value, size: SpotTokens.smallSwatch)
            }
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
            HStack(spacing: SpotTokens.choiceChevronGap) {
                Text(options.first { $0.id == value }?.title ?? options.first?.title ?? "")
                    .font(SpotType.detail)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(SpotType.mark)
                    .modifier(SpotSecondaryText())
            }
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

    private func number(_ part: SpotPart, _ frame: PartFrame) -> some View {
        let look = part.numberLook(inSheet: frame.rect.size) ?? .stat
        let inset = part.look == .bare ? 0 : look == .ring ? SpotTokens.partGap : SpotTokens.padding
        return SpotNumberView(part: part, look: look, font: SpotType.number, leastScale: SpotType.leastValueScale, alignment: part.look == .bare ? .trailing : .leading, inset: inset)
            .frame(width: frame.rect.width, height: frame.rect.height)
            .background(SpotTheme.ink.opacity(part.look == .bare ? 0 : SpotTheme.fill), in: shape)
    }

    @ViewBuilder
    private func textArea(_ part: SpotPart, _ frame: PartFrame, text: String, placeholder: String?, isReadOnly: Bool) -> some View {
        let inset = SpotTokens.padding
        let line = max((frame.rect.height - SpotType.titleLine) / 2, 0)
        let space = frame.rect.height > SpotTokens.listRow
            ? EdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
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
