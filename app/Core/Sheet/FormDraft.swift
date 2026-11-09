import Foundation

/// A form with what the person has typed so far.
public struct FormDraft: Equatable, Sendable {
    public let form: ItemForm
    public private(set) var values: [String: String]
    /// The options of a form of one choice as rows, with its value selected.
    public private(set) var choices: ItemList?

    /// Starts from the values the form gives. A prefill goes into the first field when that field is empty.
    public init(form: ItemForm, prefill: String = "") {
        self.form = form
        var values: [String: String] = [:]
        for field in form.fields { values[field.name] = field.value ?? "" }
        if let first = form.fields.first, values[first.name]?.isEmpty == true { values[first.name] = prefill }
        self.values = values
        if let choice = form.soleChoice {
            choices = ItemList(items: choice.options.map { SpotItem(title: $0.title, run: $0.id) })
            choices?.select(run: values[choice.name] ?? "")
        }
    }

    /// Selects the row of the choice this many rows away, and takes its option as the value.
    public mutating func move(by step: Int) {
        choices?.move(by: step)
        takeChoice()
    }

    /// Selects the row of this option, and takes it as the value.
    public mutating func choose(_ id: String) {
        choices?.select(run: id)
        takeChoice()
    }

    private mutating func takeChoice() {
        guard let choice = form.soleChoice, let id = choices?.selectedItem?.run else { return }
        values[choice.name] = id
    }

    public mutating func set(_ text: String, for name: String) {
        values[name] = text
    }

    /// The first required field with nothing in it.
    public var missing: ItemForm.Field? {
        form.fields.first { field in
            field.required == true && (values[field.name] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// The values as one block, for the command to read on its standard input.
    public var text: String {
        TextBlock(fields: values.sorted { $0.key < $1.key }.map { .init(key: $0.key, value: $0.value) }).text
    }
}
