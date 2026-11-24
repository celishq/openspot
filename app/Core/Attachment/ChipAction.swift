import Foundation

struct ChipAction: Equatable, Sendable {
    let action: Manifest.Action
    let input: Manifest.Parameter

    init?(_ action: Manifest.Action, takes kind: AttachmentValue.Kind) {
        let required = action.inputs.filter(\.isRequired)
        guard action.title != nil, required.count == 1, let input = required.first, Self.type(input.type, takes: kind) else { return nil }
        self.action = action
        self.input = input
    }

    var isPatterned: Bool {
        input.pattern != nil
    }

    func fits(_ value: AttachmentValue) -> Bool {
        input.fault(in: value.values) == nil
    }

    func inputs(for value: AttachmentValue) -> [TextBlock.Field] {
        let titled = input.name != Self.title && action.inputs.contains { $0.name == Self.title }
        let title = titled ? value.title.map { [TextBlock.Field(key: Self.title, value: $0)] } ?? [] : []
        return value.values.map { TextBlock.Field(key: input.name, value: $0) } + title
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
