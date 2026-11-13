import OpenspotCore
import SwiftUI

/// The fields of a form that a command asked for, drawn with system controls.
struct SpotFormView: View {
    let draft: FormDraft
    let onValue: (String, String) -> Void
    /// Takes a click on an option of a form of one choice, which shows its options as rows.
    var onChoose: (SpotItem) -> Void = { _ in }
    /// Reads the selected row of those options where it is called, so that a move redraws only the ring.
    var selection: (() -> Int)?
    @FocusState private var focus: String?

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
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
        case .text:
            HStack(spacing: 0) {
                TextField(
                    field.label,
                    text: value(of: field),
                    prompt: Text(field.placeholder ?? field.label).foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
                )
                .labelsHidden()
                .textFieldStyle(.plain)
                .focused($focus, equals: field.name)
            }
            .font(SpotType.body)
            .foregroundStyle(SpotTheme.ink)
            .padding(.horizontal, SpotTokens.padding)
            .frame(height: SpotTokens.listRowHeight)
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
                .padding(.horizontal, SpotTokens.padding - 5)
                .padding(.vertical, SpotTokens.padding - 5)
                .frame(height: SpotTokens.formTextHeight)
                .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
        case .choice:
            Picker(field.label, selection: value(of: field)) {
                ForEach(field.options, id: \.id) { Text($0.title).tag($0.id) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
            .frame(height: SpotTokens.listRowHeight)
        case .switch:
            Toggle(field.label, isOn: Binding(get: { draft.values[field.name] == "true" }, set: { onValue($0 ? "true" : "false", field.name) }))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .frame(height: SpotTokens.listRowHeight)
        case .slider:
            let range = field.range ?? 0...100
            FormSlider(text: draft.values[field.name] ?? "", level: Double(draft.values[field.name] ?? "") ?? range.lowerBound, range: range) {
                onValue(String(Int($0.rounded())), field.name)
            }
            .frame(height: SpotTokens.listRowHeight)
        }
    }

    private func moveFocus(from field: ItemForm.Field) {
        let fields = draft.form.fields
        guard let index = fields.firstIndex(of: field) else { return }
        focus = fields[(index + 1) % fields.count].name
    }
}

/// The slider of a form with its number beside it. It keeps its value while the person drags it, and sends it once they let
/// go, so that a tick redraws only it.
private struct FormSlider: View {
    let text: String
    let level: Double
    let range: ClosedRange<Double>
    let onEnd: (Double) -> Void
    @State private var dragged: Double?

    var body: some View {
        HStack(spacing: SpotTokens.padding) {
            Slider(value: Binding(get: { dragged ?? level }, set: { dragged = $0 }), in: range) { editing in
                if !editing, let dragged { onEnd(dragged); self.dragged = nil }
            }
            .controlSize(.small)
            .tint(SpotTheme.ink)
            .labelsHidden()
            Text(dragged.map { String(Int($0.rounded())) } ?? text)
                .font(SpotType.detail)
                .monospacedDigit()
                .modifier(SpotSecondaryText())
        }
    }
}
