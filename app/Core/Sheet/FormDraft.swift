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
            choices = ItemList(items: choice.options.map { option in
                let icon = Icon(text: option.icon)
                return SpotItem(
                    title: option.title, run: option.id, symbol: icon?.symbol, file: icon?.file, image: icon?.image, glyph: icon?.glyph,
                    isOn: choice.picks?.contains(option.id) ?? false
                )
            })
            choices?.select(run: values[choice.name] ?? "")
        }
    }

    /// Starts from the form that a script answered with, on the row that the last draft had selected while the form has it.
    public init(form: ItemForm, after draft: FormDraft) {
        self.init(form: form)
        if let run = draft.choices?.selectedItem?.run, choices?.shown.contains(where: { $0.run == run }) == true { choose(run) }
    }

    /// Whether its one choice picks several options, each of which a press turns on or off.
    public var isMultiple: Bool {
        form.soleChoice?.picks != nil
    }

    /// The draft that Select all sends: each option that is not picked, one per line. Nil when each one is picked, or when
    /// the choice picks one.
    public func selectingAll() -> FormDraft? {
        guard let choice = form.soleChoice, let picks = choice.picks else { return nil }
        let rest = choice.options.map(\.id).filter { !picks.contains($0) }
        guard !rest.isEmpty else { return nil }
        var draft = self
        draft.values[choice.name] = rest.joined(separator: "\n")
        return draft
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
