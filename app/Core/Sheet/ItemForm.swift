import Foundation

/// A form that a command prints, and Openspot draws.
public struct ItemForm: Equatable, Sendable {
    public struct Field: Equatable, Sendable {
        public enum Kind: String, Sendable {
            case text
            case multiline
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
        /// The options of a choice.
        public let options: [SpotPart.Option]
        /// The options that a choice of several has picked, or nil for a choice of one.
        public let picks: Set<String>?
        /// The lowest and the highest level of a slider.
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

        /// Reads a `field`, `choice`, `switch` or `slider` block. A choice starts on its first option, and a slider on its
        /// lowest level, so that each one sends a value. A choice with `type=multiple` picks each option of a `value` line.
        init?(block: TextBlock) {
            guard let kind = block.fields.first?.key, let name = block.value(kind), let label = block.value("title") else { return nil }
            switch kind {
            case "field":
                let type = block.value("type").flatMap(Kind.init).flatMap { [.text, .multiline].contains($0) ? $0 : nil } ?? .text
                self.init(name: name, label: label, type: type, value: block.value("text") ?? block.value("value"), required: block.flag("required"), placeholder: block.value("placeholder"))
            case "choice" where block.value("type") == "multiple":
                let options = block.values("option").map(SpotPart.option)
                self.init(name: name, label: label, type: .choice, value: options.first?.id, options: options, picks: Set(block.values("value")))
            case "choice":
                let options = block.values("option").map(SpotPart.option)
                self.init(name: name, label: label, type: .choice, value: block.value("value") ?? options.first?.id, options: options)
            case "switch":
                self.init(name: name, label: label, type: .switch, value: block.flag("on") == true ? "true" : "false")
            case "slider":
                let low = block.number("min") ?? 0
                let range = low...max(block.number("max") ?? 100, low + 1)
                let level = min(max(block.number("level") ?? low, range.lowerBound), range.upperBound)
                self.init(name: name, label: label, type: .slider, value: String(Int(level.rounded())), range: range)
            default:
                return nil
            }
        }
    }

    public let title: String
    public let fields: [Field]

    public init(title: String, fields: [Field]) {
        self.title = title
        self.fields = fields
    }

    /// The choice of a form that has nothing else, whose options show as rows.
    public var soleChoice: Field? {
        fields.count == 1 && fields[0].type == .choice ? fields[0] : nil
    }

    /// Reads a form from what a script prints. It needs a title, and a title for each field.
    public init?(output: PluginOutput) {
        guard let title = output.summary?.value("title") else { return nil }
        let fields = output.fields.compactMap(Field.init(block:))
        guard fields.count == output.fields.count else { return nil }
        self.init(title: title, fields: fields)
    }
}
