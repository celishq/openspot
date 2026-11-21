import OpenspotCore
import SwiftUI

struct SpotFormView: View {
    @Environment(\.spotSurfaceEdge) private var surface
    let draft: FormDraft
    let onValue: (String, String) -> Void
    var onChoose: (SpotItem) -> Void = { _ in }
    var selection: (() -> Int)?
    var focused: String?
    var onFocus: (String?) -> Void = { _ in }
    var onSave: () -> Void = {}
    var onSend: (String, String) -> Void = { _, _ in }
    @FocusState private var focus: String?

    private var shape: SpotRoundShape {
        SpotRoundShape(surface.inner())
    }

    var body: some View {
        if let choices = draft.choices {
            SpotItemsView(list: choices, onRun: onChoose, selection: selection)
        } else {
            fields
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: SpotTokens.formFieldGap) {
            ScrollViewReader { scroll in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: SpotTokens.formFieldGap) {
                        ForEach(draft.form.fields, id: \.name) { field in
                            VStack(alignment: .leading, spacing: SpotTokens.formLabelGap) {
                                Text(field.label)
                                    .font(SpotType.detail)
                                    .modifier(SpotSecondaryText())
                                    .frame(height: SpotTokens.formLabelHeight)
                                control(for: field)
                                    .modifier(StopRing(isFocused: focused == field.name && field.type != .switch, hasBox: true))
                            }
                            .padding(.vertical, ringRoom)
                            .id(field.name)
                            .padding(.vertical, -ringRoom)
                        }
                    }
                    .padding(ringRoom)
                }
                .scrollIndicators(.never)
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: SpotTokens.formFieldsHeight(draft.form) + 2 * ringRoom)
                .padding(-ringRoom)
                .onChange(of: focused) { _, name in
                    guard let name, name != FormDraft.save else { return }
                    scroll.scrollTo(name)
                }
            }
            Button(action: onSave) {
                Text("Save")
                    .font(SpotType.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: SpotTokens.listRow)
                    .spotFill(isActive: true, in: shape)
                    .contentShape(shape)
            }
            .buttonStyle(.plain)
            .modifier(StopRing(isFocused: focused == FormDraft.save, hasBox: true))
        }
        .onAppear {
            DispatchQueue.main.async {
                focus = typed(focused ?? draft.form.fields.first?.name)
                DispatchQueue.main.async { NSApp.keyWindow?.placeCaretAtEnd() }
            }
        }
        .onChange(of: focused) { _, name in
            let next = typed(name)
            guard focus != next else { return }
            focus = next
            if next != nil { DispatchQueue.main.async { NSApp.keyWindow?.placeCaretAtEnd() } }
        }
        .onChange(of: focus) { _, name in
            if name != focused, name != nil || typed(focused) != nil { onFocus(name) }
        }
    }

    private var ringRoom: CGFloat {
        SpotTokens.focusGap + SpotTokens.ring
    }

    private func typed(_ name: String?) -> String? {
        draft.form.fields.first { $0.name == name && $0.takesFocus }?.name
    }

    private func value(of field: ItemForm.Field) -> Binding<String> {
        Binding(get: { draft.values[field.name] ?? "" }, set: { onValue($0, field.name) })
    }

    @ViewBuilder
    private func control(for field: ItemForm.Field) -> some View {
        switch field.type {
        case .text, .secret:
            HStack(spacing: 0) {
                let prompt = Text(field.placeholder ?? field.label).foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
                Group {
                    if field.type == .secret {
                        SecureField(field.label, text: value(of: field), prompt: prompt)
                    } else {
                        TextField(field.label, text: value(of: field), prompt: prompt)
                    }
                }
                .labelsHidden()
                .textFieldStyle(.plain)
                .focused($focus, equals: field.name)
            }
            .font(SpotType.body)
            .foregroundStyle(SpotTheme.ink)
            .padding(.horizontal, SpotTokens.padding)
            .frame(height: SpotTokens.listRow)
            .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
        case .multiline:
            TextEditor(text: value(of: field))
                .scrollContentBackground(.hidden)
                .font(SpotType.body)
                .foregroundStyle(SpotTheme.ink)
                .focused($focus, equals: field.name)
                .onKeyPress(.tab) {
                    moveFocus(from: field)
                    return .handled
                }
                .padding(.horizontal, SpotTokens.formInset)
                .padding(.vertical, SpotTokens.formInset)
                .frame(height: SpotTokens.formTextHeight)
                .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
        case .choice:
            Menu {
                ForEach(draft.options[field.name] ?? field.options, id: \.id) { option in
                    if field.picks != nil {
                        Toggle(option.title, isOn: Binding(
                            get: { draft.picked[field.name]?.contains(option.id) == true },
                            set: { onValue(draft.picking(option.id, $0, in: field), field.name) }
                        ))
                    } else {
                        Button(option.title) {
                            if option.sends { onSend(option.id, field.name) } else { onValue(option.id, field.name) }
                        }
                    }
                }
            } label: {
                HStack(spacing: 0) {
                    Text(draft.menuTitles[field.name] ?? field.label)
                        .lineLimit(1)
                        .font(SpotType.body)
                        .foregroundStyle(SpotTheme.ink)
                    Spacer(minLength: SpotTokens.padding)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(SpotType.detail)
                        .modifier(SpotSecondaryText())
                }
                .padding(.horizontal, SpotTokens.padding)
                .frame(height: SpotTokens.listRow)
                .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
                .contentShape(shape)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
        case .switch:
            Toggle(field.label, isOn: Binding(get: { draft.values[field.name] == "true" }, set: { onValue($0 ? "true" : "false", field.name) }))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .tint(SpotTheme.accent)
                .modifier(StopRing(isFocused: focused == field.name, hasBox: false))
                .frame(height: SpotTokens.listRow)
        case .slider:
            let range = field.range ?? 0...100
            SpotSlider(level: Double(draft.values[field.name] ?? "") ?? range.lowerBound, range: range, words: draft.values[field.name] ?? "") {
                onValue(String(Int($0.rounded())), field.name)
            }
            .frame(height: SpotTokens.listRow)
        }
    }

    private struct StopRing: ViewModifier {
        @Environment(\.spotSurfaceEdge) private var surface
        let isFocused: Bool
        let hasBox: Bool

        func body(content: Content) -> some View {
            let gap = SpotTokens.focusGap
            if hasBox {
                content.overlay(Color.clear.modifier(SpotSelectionRing(isSelected: isFocused, shape: SpotRoundShape(surface.inner(by: SpotTokens.padding - gap)))).padding(-gap))
            } else {
                content.overlay(Color.clear.modifier(SpotSelectionRing(isSelected: isFocused, shape: Capsule())).padding(-gap))
            }
        }
    }

    private func moveFocus(from field: ItemForm.Field) {
        let fields = draft.form.fields
        guard let index = fields.firstIndex(of: field) else { return }
        focus = fields[(index + 1) % fields.count].name
    }
}
