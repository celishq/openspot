import Foundation

public struct FormDraft: Equatable, Sendable {
    public static let save = "\u{1}save"

    public let form: ItemForm
    public private(set) var values: [String: String]
    public private(set) var choices: ItemList?
    public private(set) var focus: String?
    public private(set) var picking: String?
    public private(set) var picked: [String: Set<String>] = [:]
    public private(set) var menuTitles: [String: String] = [:]

    public init(form: ItemForm, prefill: String = "") {
        self.form = form
        focus = form.fields.first { $0.takesFocus }?.name
        var values: [String: String] = [:]
        for field in form.fields { values[field.name] = field.value ?? "" }
        if form.soleChoice == nil {
            for field in form.fields where field.type == .choice {
                guard let picks = field.picks else { continue }
                values[field.name] = field.options.map(\.id).filter(picks.contains).joined(separator: "\n")
            }
        }
        if let first = form.fields.first(where: { $0.type == .text }), values[first.name]?.isEmpty == true { values[first.name] = prefill }
        self.values = values
        for field in form.fields where field.type == .choice { retitle(field) }
        if let choice = form.soleChoice {
            choices = ItemList(items: choice.options.map { option in
                SpotItem(
                    title: option.title, run: option.id, picture: Icon(text: option.icon),
                    isOn: choice.picks?.contains(option.id) ?? (option.id == choice.value)
                )
            })
            choices?.select(run: values[choice.name] ?? "")
        }
    }

    public init(form: ItemForm, after draft: FormDraft) {
        self.init(form: form)
        if let kept = focusing(draft.focus), kept != Self.save { focus = kept }
        search(draft.choices?.query ?? "")
        if let run = draft.choices?.selectedItem?.run, choices?.shown.contains(where: { $0.run == run }) == true { choose(run) }
    }

    public mutating func search(_ text: String) {
        guard choices?.search(text) == true else { return }
        takeChoice()
    }

    public var isMultiple: Bool {
        form.soleChoice?.picks != nil
    }

    public func selectingAll() -> FormDraft? {
        guard let choice = form.soleChoice, let picks = choice.picks else { return nil }
        let rest = choice.options.map(\.id).filter { !picks.contains($0) }
        guard !rest.isEmpty else { return nil }
        var draft = self
        draft.values[choice.name] = rest.joined(separator: "\n")
        return draft
    }

    public mutating func move(by step: Int) {
        choices?.move(by: step)
        takeChoice()
    }

    public mutating func choose(_ id: String) {
        choices?.select(run: id)
        takeChoice()
    }

    private mutating func takeChoice() {
        guard let choice = form.soleChoice, let id = choices?.selectedItem?.run else { return }
        values[choice.name] = id
    }

    public func picks(of field: ItemForm.Field) -> [String] {
        (values[field.name] ?? "").split(separator: "\n").map(String.init)
    }

    public func picking(_ id: String, _ isOn: Bool, in field: ItemForm.Field) -> String {
        let now = picked[field.name] ?? []
        return field.options.map(\.id).filter { $0 == id ? isOn : now.contains($0) }.joined(separator: "\n")
    }

    public mutating func set(_ text: String, for name: String) {
        values[name] = text
        if let field = form.fields.first(where: { $0.name == name && $0.type == .choice }) { retitle(field) }
    }

    private mutating func retitle(_ field: ItemForm.Field) {
        if field.picks != nil {
            let picks = Set(picks(of: field))
            picked[field.name] = picks
            let titles = field.options.filter { picks.contains($0.id) }.map(\.title)
            menuTitles[field.name] = titles.isEmpty ? (field.placeholder ?? "None") : titles.joined(separator: ", ")
        } else {
            menuTitles[field.name] = field.options.first { $0.id == values[field.name] }?.title ?? field.placeholder ?? field.label
        }
    }

    public var pickedField: ItemForm.Field? {
        form.fields.first { $0.name == picking }
    }

    public mutating func pick() -> Bool {
        guard let field = focusedField, field.type == .choice, !field.options.isEmpty else { return false }
        picking = field.name
        choices = list(of: field)
        choices?.select(run: field.picks == nil ? values[field.name] ?? "" : field.options[0].id)
        return true
    }

    public mutating func endPicking() {
        picking = nil
        choices = nil
    }

    public mutating func takePick() -> SpotPart.Option? {
        guard let field = pickedField, let id = choices?.selectedItem?.run, let option = field.options.first(where: { $0.id == id }) else { return nil }
        guard field.picks != nil else {
            set(id, for: field.name)
            endPicking()
            return option
        }
        set(picking(id, picked[field.name]?.contains(id) != true, in: field), for: field.name)
        let query = choices?.query ?? ""
        choices = list(of: field)
        choices?.search(query)
        choices?.select(run: id)
        return option
    }

    private func list(of field: ItemForm.Field) -> ItemList {
        let picks = picked[field.name]
        return ItemList(items: field.options.map { option in
            SpotItem(title: option.title, run: option.id, picture: Icon(text: option.icon), isOn: picks?.contains(option.id) ?? (option.id == values[field.name]))
        })
    }

    public var focusedField: ItemForm.Field? {
        form.fields.first { $0.name == focus }
    }

    public var stops: [String] {
        form.fields.filter(\.isStop).map(\.name) + [Self.save]
    }

    public func focusing(_ name: String?) -> String? {
        guard let name, stops.contains(name) else { return nil }
        return name
    }

    public func focus(movedBy step: Int) -> String? {
        let names = stops
        guard let now = names.firstIndex(where: { $0 == focus }) else { return step > 0 ? names.first : names.last }
        return names[min(max(now + step, 0), names.count - 1)]
    }

    public mutating func turn(by step: Int) -> Bool {
        guard let field = focusedField else { return false }
        switch field.type {
        case .choice where field.picks == nil:
            let ids = field.options.filter { !$0.sends }.map(\.id)
            guard !ids.isEmpty else { return false }
            let now = ids.firstIndex(of: values[field.name] ?? "") ?? (step > 0 ? -1 : ids.count)
            let next = ids[min(max(now + step, 0), ids.count - 1)]
            if values[field.name] != next { set(next, for: field.name) }
            return true
        case .switch:
            values[field.name] = values[field.name] == "true" ? "false" : "true"
            return true
        default:
            return false
        }
    }

    public mutating func focus(on name: String?) {
        focus = focusing(name)
    }

    public var missing: ItemForm.Field? {
        form.fields.first { field in
            field.required == true && (values[field.name] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public var inputs: [TextBlock.Field] {
        values.sorted { $0.key < $1.key }.map { .init(key: $0.key, value: $0.value) }
    }
}
