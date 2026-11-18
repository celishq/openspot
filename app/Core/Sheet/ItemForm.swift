import Foundation

public struct ItemForm: Equatable, Sendable {
    public struct Field: Equatable, Sendable {
        public enum Kind: String, Sendable {
            case text
            case multiline
            case secret
            case choice
            case `switch`
            case slider
        }

        public let name: String
        public let label: String
        public let type: Kind
        public let value: String?
        public let required: Bool?
        public let placeholder: String?
        public let options: [SpotPart.Option]
        public let picks: Set<String>?
        public let range: ClosedRange<Double>?

        public init(
            name: String,
            label: String,
            type: Kind = .text,
            value: String? = nil,
            required: Bool? = nil,
            placeholder: String? = nil,
            options: [SpotPart.Option] = [],
            picks: Set<String>? = nil,
            range: ClosedRange<Double>? = nil
        ) {
            self.name = name
            self.label = label
            self.type = type
            self.value = value
            self.required = required
            self.placeholder = placeholder
            self.options = options
            self.picks = picks
            self.range = range
        }
    }

    public let title: String
    public let fields: [Field]

    public init(title: String, fields: [Field]) {
        self.title = title
        self.fields = fields
    }

    public var soleChoice: Field? {
        fields.count == 1 && fields[0].type == .choice ? fields[0] : nil
    }

    public init?(output: SpotOutput) {
        guard let title = output.summary?.value(RootKey.title) else { return nil }
        let fields = output.fields.compactMap { $0.kind.formField(of: $0.block) }
        guard fields.count == output.fields.count else { return nil }
        self.init(title: title, fields: fields)
    }
}
