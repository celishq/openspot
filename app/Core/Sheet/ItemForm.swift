import Foundation

/// A form that a command prints, and Openspot draws.
public struct ItemForm: Equatable, Sendable {
    public struct Field: Equatable, Sendable {
        public enum Kind: String, Sendable {
            case text
            case multiline
        }

        public let name: String
        public let label: String
        public let type: Kind
        public let value: String?
        public let required: Bool?
        public let placeholder: String?

        public init(name: String, label: String, type: Kind = .text, value: String? = nil, required: Bool? = nil, placeholder: String? = nil) {
            self.name = name
            self.label = label
            self.type = type
            self.value = value
            self.required = required
            self.placeholder = placeholder
        }
    }

    public let title: String
    public let fields: [Field]

    public init(title: String, fields: [Field]) {
        self.title = title
        self.fields = fields
    }

    /// Reads a form from what a script prints. It needs a title, and a label for each field.
    public init?(output: PluginOutput) {
        guard let title = output.summary?.value("title") else { return nil }
        let fields = output.fields.compactMap { block -> Field? in
            guard let name = block.value("field"), let label = block.value("label") else { return nil }
            return Field(
                name: name,
                label: label,
                type: block.value("type").flatMap(Field.Kind.init) ?? .text,
                value: block.value("value"),
                required: block.flag("required"),
                placeholder: block.value("placeholder")
            )
        }
        guard fields.count == output.fields.count else { return nil }
        self.init(title: title, fields: fields)
    }
}
