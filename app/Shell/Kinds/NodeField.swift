import OpenspotCore
import SwiftUI

struct NodeField: View {
    let node: ViewNode
    let look: SpotPart.Look?
    @Environment(\.spotNode) private var context

    var body: some View {
        if let part = context.host.part(of: node) {
            let host = context.host
            NodePartFrame(node: node, part: part, look: look) { size in
                FieldDrawing(part: part, size: size, isCard: context.isCard, call: context.call(of: part), isRecording: host.recordingPart == part.id, keys: host.keys, focus: context.focus, onRecord: { host.record(part) }) { context.set(part, to: $0) }
            }
        }
    }
}

private struct FieldDrawing: View {
    let part: SpotPart
    let size: CGSize
    let isCard: Bool
    let call: ScriptCall?
    let isRecording: Bool
    let keys: KeyRecording?
    let focus: FocusState<String?>.Binding?
    let onRecord: () -> Void
    let onSet: (String) -> Void
    @Environment(\.spotSurfaceEdge) private var surface

    var body: some View {
        switch part.control {
        case .text(let text, let placeholder, let isReadOnly) where isCard:
            CardField(text: text, placeholder: placeholder ?? part.title ?? "", isReadOnly: isReadOnly, onSubmit: onSet)
        case .text(let text, let placeholder, let isReadOnly) where part.isMultiline:
            textArea(text: text, placeholder: placeholder, isReadOnly: isReadOnly)
                .overlay(alignment: .topTrailing) { mark }
        case .text(let text, let placeholder, let isReadOnly):
            textLine(text: text, placeholder: placeholder, isReadOnly: isReadOnly)
                .overlay(alignment: .trailing) { mark }
        case .secret(let text, let placeholder):
            secretLine(text: text, placeholder: placeholder)
        case .slider(let level, let low, let high):
            slider(level: level, range: low...max(high, low + 1))
        case .shortcut(let text) where isCard:
            SpotKeyLabel(text: text, isRecording: false)
        case .shortcut(let text):
            Button(action: onRecord) {
                LiveKeycaps(value: text, isRecording: isRecording, keys: keys)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(SpotTheme.well, in: shape)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        default:
            EmptyView()
        }
    }

    private var shape: SpotRoundShape {
        SpotRoundShape(surface.inner())
    }

    @ViewBuilder
    private var mark: some View {
        if let call {
            SpotWorkMark(call: call, side: SpotTokens.workMark, stops: part.isPressable)
                .padding(SpotTokens.controlPadding)
        }
    }

    @ViewBuilder
    private func slider(level: Double, range: ClosedRange<Double>) -> some View {
        let control = SpotSlider(level: level, range: range) { onSet(String(Int($0.rounded()))) }
        if isCard {
            control
        } else {
            HStack(spacing: SpotTokens.partLineGap) {
                if let title = part.title {
                    Text(title)
                        .font(SpotType.body)
                        .foregroundStyle(SpotTheme.ink)
                        .lineLimit(1)
                }
                if let call {
                    SpotWorkMark(call: call, side: SpotTokens.workMark, stops: part.isPressable)
                } else if let icon = part.icon {
                    NodeIcon(icon: icon, side: SpotTokens.partSymbolWidth)
                        .foregroundStyle(SpotTheme.ink)
                }
                control
            }
        }
    }

    private func textLine(text: String, placeholder: String?, isReadOnly: Bool) -> some View {
        ZStack(alignment: .leading) {
            if isReadOnly {
                Text(text)
                    .lineLimit(1)
                    .textSelection(.enabled)
            } else {
                SpotTextLine(label: part.title ?? part.id, text: text) { onSet($0) }
                    .modifier(FieldFocus(focus: focus, id: part.id))
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

    private func secretLine(text: String, placeholder: String?) -> some View {
        let prompt = Text(placeholder ?? part.title ?? "").foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
        return SecureField(part.title ?? part.id, text: Binding(get: { text }, set: { onSet($0) }), prompt: prompt)
            .labelsHidden()
            .textFieldStyle(.plain)
            .modifier(FieldFocus(focus: focus, id: part.id))
            .padding(.horizontal, SpotTokens.padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .font(SpotType.body)
            .foregroundStyle(SpotTheme.ink)
            .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
    }

    @ViewBuilder
    private func textArea(text: String, placeholder: String?, isReadOnly: Bool) -> some View {
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
                .clipShape(shape)
            } else {
                TextEditor(text: Binding(get: { text }, set: { onSet($0) }))
                    .scrollContentBackground(.hidden)
                    .modifier(FieldFocus(focus: focus, id: part.id))
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

private struct FieldFocus: ViewModifier {
    let focus: FocusState<String?>.Binding?
    let id: String

    func body(content: Content) -> some View {
        if let focus { content.focused(focus, equals: id) } else { content }
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

private struct CardField: View {
    let text: String
    let placeholder: String
    let isReadOnly: Bool
    let onSubmit: (String) -> Void
    @State private var typed: String?
    @Environment(\.spotIsOnSolid) private var isOnSolid

    var body: some View {
        TextField(placeholder, text: Binding(get: { typed ?? text }, set: { typed = $0 }))
            .textFieldStyle(.plain)
            .font(SpotType.body)
            .foregroundStyle(SpotTheme.ink(onSolid: isOnSolid))
            .disabled(isReadOnly)
            .onSubmit {
                if let typed { onSubmit(typed) }
                typed = nil
            }
    }
}
