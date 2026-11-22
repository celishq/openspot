import AppKit
import OpenspotCore
import SwiftUI

struct SheetPartView: View {
    let node: ViewNode
    let label: AnyView?
    let look: SpotPart.Look?
    @Environment(\.spotSurfaceEdge) private var surface
    @Environment(\.spotNode) private var context

    private var actions: any NodeActions {
        context.actions
    }

    private var shape: SpotRoundShape {
        SpotRoundShape(surface.inner())
    }

    var body: some View {
        if let part = actions.part(of: node) {
            draw(part)
        }
    }

    @ViewBuilder
    private func draw(_ part: SpotPart) -> some View {
        let natural = node.naturalSize
        let height = natural.height
        let size = CGSize(width: SpotTokens.partsWidth, height: height)
        Group {
            if let label {
                Button { actions.press(part) } label: {
                    label
                        .spotHover(in: shape)
                        .contentShape(shape)
                }
                .buttonStyle(.plain)
            } else if part.fillsHeight {
                GeometryReader { room in
                    content(part, look, room.size)
                }
                .frame(minHeight: height, idealHeight: height)
                .frame(idealWidth: natural.width)
            } else {
                content(part, look, size)
                    .frame(maxWidth: part.fillsWidth(as: look) ? .infinity : nil, minHeight: height, maxHeight: .infinity, alignment: part.fillsWidth(as: look) ? .leading : .center)
            }
        }
        .background {
            if part.isFocusable {
                Color.clear.modifier(PartRing(id: part.id, actions: actions, hasBox: label != nil || hasBox(part, look), shape: shape))
            }
        }
    }

    private func hasBox(_ part: SpotPart, _ look: SpotPart.Look?) -> Bool {
        if part.isEditable || look == .tile { return true }
        guard part.press == .line else { return false }
        return switch look {
        case .chip, .bare: false
        default: true
        }
    }

    @ViewBuilder
    private func content(_ part: SpotPart, _ look: SpotPart.Look?, _ size: CGSize) -> some View {
        switch part.control {
        case .text(let text, let placeholder, let isReadOnly) where part.isMultiline:
            textArea(part, size, text: text, placeholder: placeholder, isReadOnly: isReadOnly)
                .overlay(alignment: .topTrailing) { cornerMark(part, size) }
        case .text(let text, let placeholder, let isReadOnly):
            textLine(part, text: text, placeholder: placeholder, isReadOnly: isReadOnly)
                .overlay(alignment: .trailing) { cornerMark(part, size) }
        case .slider(let level, let low, let high):
            slider(part, level: level, low: low, high: high)
        case .swatches(let colors, let value) where colors.count > 1:
            HStack(spacing: SpotTokens.partLineGap) {
                mark(part)
                swatches(part, colors: colors, value: value)
            }
        case .list(let items, let value):
            list(part, items: items, value: value)
                .overlay(alignment: .topTrailing) { cornerMark(part, size) }
        case .number:
            number(part, look, size)
        case .shortcut(let text):
            shortcut(part, text: text)
        default:
            if part.press == .line {
                lineButton(part, look, size)
            } else {
                line(part, look, size).modifier(TileLook(isOn: look == .tile))
            }
        }
    }

    @ViewBuilder
    private func mark(_ part: SpotPart) -> some View {
        if let call = actions.act(of: part) {
            SpotWorkMark(call: call, side: SpotTokens.workMark, stops: part.isPressable)
        }
    }

    private func cornerMark(_ part: SpotPart, _ size: CGSize) -> some View {
        mark(part).padding(SpotTokens.controlPadding)
    }

    private func line(_ part: SpotPart, _ look: SpotPart.Look?, _ size: CGSize) -> some View {
        HStack(spacing: size.width < SpotTokens.narrowCell ? SpotTokens.narrowGap : SpotTokens.partLineGap) {
            if !hasRoundMark(part), actions.act(of: part) != nil {
                mark(part)
            } else if let icon = part.icon {
                NodeIcon(icon: icon, side: SpotTokens.partSymbolWidth)
                    .modifier(SpotSecondaryText())
                    .frame(width: SpotTokens.partSymbolWidth)
            }
            else if context.panel?.keepsIconColumn(part) == true {
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
            if case .round(let icon) = part.press {
                SpotRoundButton(
                    icon: icon,
                    label: part.title ?? part.id.capitalized,
                    act: actions.act(of: part),
                    size: min(size.width, size.height, SpotTokens.partMaxRound),
                    look: look == .strong ? .strong : look == .bare ? .bare : .plain
                ) { actions.press(part) }
            }
            control(part, size)
        }
        .modifier(SpotColorBar(color: part.color))
    }

    private func hasRoundMark(_ part: SpotPart) -> Bool {
        if case .round = part.press { return true }
        return false
    }

    @ViewBuilder
    private func pressLabel(_ part: SpotPart, words: String, font: Font) -> some View {
        if let call = actions.act(of: part) {
            HStack(spacing: SpotTokens.placeGap / 2) {
                SpotWorkMark(call: call, side: SpotTokens.workMark)
                Text("Stop").font(font).lineLimit(1)
            }
        } else if let icon = part.icon {
            HStack(spacing: SpotTokens.placeGap / 2) {
                NodeIcon(icon: icon, side: SpotTokens.partSymbolWidth)
                if let title = part.title { Text(title).lineLimit(1) }
            }
            .font(font)
        } else {
            Text(words).font(font).lineLimit(1)
        }
    }

    @ViewBuilder
    private func lineButton(_ part: SpotPart, _ look: SpotPart.Look?, _ size: CGSize) -> some View {
        Button { actions.press(part) } label: {
            switch look {
            case .chip:
                pressLabel(part, words: part.title ?? part.id, font: SpotType.action)
                    .padding(.horizontal, SpotTokens.padding)
                    .padding(.vertical, SpotTokens.chipPaddingY)
                    .fixedSize()
                    .spotFill(isActive: actions.act(of: part) != nil, otherwise: SpotTheme.ink.opacity(SpotTheme.selectedFill), in: Capsule())
                    .spotHover(isOnSolid: actions.act(of: part) != nil, in: Capsule())
                    .contentShape(Capsule())
            case .bare:
                HStack {
                    line(part, look, size)
                    if part.detail == nil, let key = part.key {
                        Text(key.label).font(SpotType.detail).modifier(SpotSecondaryText())
                    }
                }
                .contentShape(Rectangle())
            case .strong:
                centeredLine(part, isActive: true)
            case .tile:
                line(part, look, size)
                    .modifier(TileLook(isOn: true))
                    .spotHover(in: shape)
                    .contentShape(shape)
            default:
                centeredLine(part, isActive: actions.act(of: part) != nil)
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
    private func control(_ part: SpotPart, _ size: CGSize) -> some View {
        switch part.control {
        case .toggle(let on) where part.isTick:
            SpotTick(isOn: on, words: EmptyView()) { actions.set(part, to: $0 ? "true" : "false") }
                .fixedSize()
        case .toggle(let on):
            Toggle(part.title ?? part.id, isOn: Binding(get: { on }, set: { actions.set(part, to: $0 ? "true" : "false") }))
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
            Picker(part.title ?? part.id, selection: Binding(get: { value ?? "" }, set: { actions.set(part, to: $0) })) {
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
                Color.clear.onChange(of: actions.menuOpening) { _, opening in
                    guard opening?.part == part.id else { return }
                    let rect = room.frame(in: .global)
                    DispatchQueue.main.async {
                        SpotChoiceMenu.popUp(options: options, value: value, under: rect) { actions.set(part, to: $0) }
                    }
                }
            }
        }
    }

    private func shortcut(_ part: SpotPart, text: String) -> some View {
        Button { actions.record(part) } label: {
            LiveKeycaps(value: text, isRecording: actions.recordingPart == part.id, keys: actions.keys)
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
            if actions.act(of: part) != nil {
                mark(part)
            } else if let icon = part.icon {
                NodeIcon(icon: icon, side: SpotTokens.partSymbolWidth)
                    .foregroundStyle(SpotTheme.ink)
            }
            SpotSlider(level: level, range: low...max(high, low + 1)) { actions.set(part, to: String(Int($0.rounded()))) }
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
        Button { actions.set(part, to: color) } label: {
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
                    Button { actions.set(part, to: item.id) } label: {
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

    private func number(_ part: SpotPart, _ look: SpotPart.Look?, _ size: CGSize) -> some View {
        let figure = part.number?.look ?? .stat
        let inset = look == .bare ? 0 : figure == .ring ? SpotTokens.partGap : SpotTokens.padding
        return SpotNumberView(part: part, look: figure, font: SpotType.number, leastScale: SpotType.leastValueScale, alignment: look == .bare ? .trailing : .leading, inset: inset)
            .frame(width: size.width, height: size.height)
            .background(SpotTheme.ink.opacity(look == .bare ? 0 : SpotTheme.fill), in: shape)
    }

    private func textLine(_ part: SpotPart, text: String, placeholder: String?, isReadOnly: Bool) -> some View {
        ZStack(alignment: .leading) {
            if isReadOnly {
                Text(text)
                    .lineLimit(1)
                    .textSelection(.enabled)
            } else {
                SpotTextLine(label: part.title ?? part.id, text: text) { actions.set(part, to: $0) }
                    .modifier(PartFocus(focus: context.focus, id: part.id))
            }
            if text.isEmpty, let placeholder {
                Text(placeholder)
                    .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, SpotTokens.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .font(SpotType.body)
        .foregroundStyle(SpotTheme.ink)
        .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
    }

    @ViewBuilder
    private func textArea(_ part: SpotPart, _ size: CGSize, text: String, placeholder: String?, isReadOnly: Bool) -> some View {
        let inset = SpotTokens.padding
        let line = max((size.height - SpotType.titleLine) / 2, 0)
        let space = size.height > SpotTokens.listRow
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
                TextEditor(text: Binding(get: { text }, set: { actions.set(part, to: $0) }))
                    .scrollContentBackground(.hidden)
                    .modifier(PartFocus(focus: context.focus, id: part.id))
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

private struct PartRing: ViewModifier {
    @Environment(\.spotSurfaceEdge) private var surface
    let id: String
    let actions: any NodeActions
    let hasBox: Bool
    let shape: SpotRoundShape

    func body(content: Content) -> some View {
        let isSelected = actions.selectedPart == id
        if hasBox {
            let gap = SpotTokens.focusGap
            let ring = SpotRoundShape(surface.inner(by: SpotTokens.padding - gap))
            content.modifier(SpotSelectionRing(isSelected: isSelected, shape: ring)).padding(-gap)
        } else {
            content.modifier(SpotSelectionRing(isSelected: isSelected, shape: shape)).padding(.horizontal, -SpotTokens.controlPadding)
        }
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

private struct PartFocus: ViewModifier {
    let focus: FocusState<String?>.Binding?
    let id: String

    func body(content: Content) -> some View {
        if let focus { content.focused(focus, equals: id) } else { content }
    }
}
