import OpenspotCore
import SwiftUI

struct SpotFormView: View {
    @Environment(\.spotSurfaceEdge) private var surface
    let draft: FormDraft
    let onValue: (String, String) -> Void
    var onChoose: (SpotItem) -> Void = { _ in }
    var selection: (() -> Int)?
    @FocusState private var focus: String?

    private var shape: SpotRoundShape {
        SpotRoundShape(surface.inner())
    }

    var body: some View {
        if let choices = draft.choices {
            SpotRowsView(list: choices, onRun: onChoose, selection: selection)
        } else {
            fields
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: SpotTokens.formFieldGap) {
            ForEach(draft.form.fields, id: \.name) { field in
                VStack(alignment: .leading, spacing: SpotTokens.formLabelGap) {
                    Text(field.label)
                        .font(SpotType.detail)
                        .modifier(SpotSecondaryText())
                        .frame(height: SpotTokens.formLabelHeight)
                    control(for: field)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.async { focus = draft.form.fields.first?.name }
        }
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
            Picker(field.label, selection: value(of: field)) {
                ForEach(field.options, id: \.id) { Text($0.title).tag($0.id) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
            .frame(height: SpotTokens.listRow)
        case .switch:
            Toggle(field.label, isOn: Binding(get: { draft.values[field.name] == "true" }, set: { onValue($0 ? "true" : "false", field.name) }))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .tint(SpotTheme.accent)
                .frame(height: SpotTokens.listRow)
        case .slider:
            let range = field.range ?? 0...100
            SpotSlider(level: Double(draft.values[field.name] ?? "") ?? range.lowerBound, range: range, words: draft.values[field.name] ?? "") {
                onValue(String(Int($0.rounded())), field.name)
            }
            .frame(height: SpotTokens.listRow)
        }
    }

    private func moveFocus(from field: ItemForm.Field) {
        let fields = draft.form.fields
        guard let index = fields.firstIndex(of: field) else { return }
        focus = fields[(index + 1) % fields.count].name
    }
}
