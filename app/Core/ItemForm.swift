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

    /// Reads the block a form prints. It needs a title, and a name and a label for each field.
    public init?(block: TextBlock) {
        guard let title = block.value("title") else { return nil }
        let groups = block.groups("field")
        let fields = groups.compactMap { group -> Field? in
            guard let name = group.value("field"), let label = group.value("label") else { return nil }
            return Field(
                name: name,
                label: label,
                type: group.value("type").flatMap(Field.Kind.init) ?? .text,
                value: group.value("value"),
                required: group.flag("required"),
                placeholder: group.value("placeholder")
            )
        }
        guard fields.count == groups.count else { return nil }
        self.init(title: title, fields: fields)
    }
}
