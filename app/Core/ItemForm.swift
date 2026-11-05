import Foundation

/// A form that a command prints as JSON, and Openspot draws.
public struct ItemForm: Decodable, Equatable, Sendable {
    public struct Field: Decodable, Equatable, Sendable {
        public enum Kind: String, Decodable, Sendable {
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
}
