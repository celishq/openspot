import OpenspotCore
import SwiftUI

/// The fields of a form that a command asked for, drawn with system text controls.
struct SpotFormView: View {
    let draft: FormDraft
    let onValue: (String, String) -> Void
    @FocusState private var focus: String?

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
    }

    var body: some View {
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
                    prompt: Text(field.placeholder ?? field.label).foregroundStyle(.white.opacity(SpotTokens.secondaryLight))
                )
                .labelsHidden()
                .textFieldStyle(.plain)
                .focused($focus, equals: field.name)
            }
            .font(SpotType.body)
            .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
            .padding(.horizontal, SpotTokens.padding)
            .frame(height: SpotTokens.listRowHeight)
            .background(Color.white.opacity(0.12), in: shape)
        case .multiline:
            TextEditor(text: value(of: field))
                .scrollContentBackground(.hidden)
                .font(SpotType.body)
                .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                .focused($focus, equals: field.name)
                .onKeyPress(.tab) {
                    moveFocus(from: field)
                    return .handled
                }
                .padding(.horizontal, SpotTokens.padding - 5)
                .padding(.vertical, SpotTokens.padding - 5)
                .frame(height: SpotTokens.formTextHeight)
                .background(Color.white.opacity(0.12), in: shape)
        }
    }

    private func moveFocus(from field: ItemForm.Field) {
        let fields = draft.form.fields
        guard let index = fields.firstIndex(of: field) else { return }
        focus = fields[(index + 1) % fields.count].name
    }
}
