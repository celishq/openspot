import Foundation

struct ChipAction: Equatable, Sendable {
    let name: String
    let kind: AttachmentValue.Kind
    let title: String
    let detail: String?
    let icon: String?
    let confirm: String?
    private let input: Manifest.Parameter
    private let takesTitle: Bool
    private let drop: DropKinds?

    init?(_ action: Manifest.Action, of spot: String, takes kind: AttachmentValue.Kind) {
        let required = action.inputs.filter(\.isRequired)
        guard let title = action.title, required.count == 1, let input = required.first, Self.type(input.type, takes: kind) else { return nil }
        name = action.id
        self.kind = kind
        self.title = title
        detail = spot
        icon = action.icon
        confirm = action.confirm
        self.input = input
        takesTitle = input.name != Self.title && action.inputs.contains { $0.name == Self.title }
        drop = nil
    }

    init?(drop kinds: DropKinds, title: String, detail: String?) {
        guard kinds.takesAny, let input = ScriptEntry.drop.inputs.first else { return nil }
        name = ScriptEntry.drop.name
        kind = .file
        self.title = title
        self.detail = detail
        icon = nil
        confirm = nil
        self.input = input
        takesTitle = false
        drop = kinds
    }

    var isDrop: Bool {
        drop != nil
    }

    var isPatterned: Bool {
        input.pattern != nil
    }

    func fits(_ value: AttachmentValue) -> Bool {
        guard value.kind == kind else { return false }
        return drop?.takes(value) ?? (input.fault(in: value.values) == nil)
    }

    func message(for value: AttachmentValue) -> Message {
        let title = takesTitle ? value.title.map { [TextBlock.Field(key: Self.title, value: $0)] } ?? [] : []
        return Message(name, inputs: value.values.map { TextBlock.Field(key: input.name, value: $0) } + title)
    }

    private static let title = "title"

    private static func type(_ type: ValueType, takes kind: AttachmentValue.Kind) -> Bool {
        switch kind {
        case .url: type == ValueType(.url)
        case .text: type == ValueType(.text)
        case .file: type.kind == .file
        }
    }
}
