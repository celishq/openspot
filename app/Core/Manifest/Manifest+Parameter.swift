import Foundation

extension Manifest {
    public struct Parameter: Equatable, Sendable {
        static let inputKeys: Set<String> = ["type", "required", "default", "description", "options", "pattern"]
        static let settingKeys: Set<String> = ["type", "options", "default", "title", "description", "icon"]

        public let name: String
        public let type: ValueType
        public let isRequired: Bool
        public let defaultValue: String?
        public let title: String?
        public let icon: String?
        public let detail: String?
        public let options: [String]
        public let pattern: AnswerPattern?

        init(name: String, value: ConfigDocument.Value?, keys: Set<String>, place: String) throws {
            let fault = { (reason: String) in SpotError.fault("\(Manifest.fileName): \(place) \(reason)") }
            var fields: [String: ConfigDocument.Value]
            switch value {
            case .string(let type): fields = ["type": .string(type)]
            case .table(let table): fields = table
            default: throw fault("takes a type, such as \"text\", or a table, such as { type = \"text\" }.")
            }
            if let key = fields.keys.sorted().first(where: { !keys.contains($0) }) {
                throw fault("has an unknown key: \(key). Use \(keys.sorted().joined(separator: ", ")).")
            }
            let text = { (key: String) throws -> String? in
                switch fields[key] {
                case nil: return nil
                case .string(let text): return text
                default: throw fault("takes a text in \(key).")
                }
            }
            guard let typeName = try text("type") else { throw fault("needs a type, such as type = \"text\".") }
            guard let type = ValueType(name: typeName) else {
                throw fault("has an unknown type: \(typeName). Use \(ValueType.names), or a list such as [text].")
            }
            var isRequired = false
            switch fields["required"] {
            case nil: break
            case .boolean(let flag): isRequired = flag
            default: throw fault("takes true or false in required.")
            }
            var options: [String] = []
            switch fields["options"] {
            case nil: break
            case .strings(let items): options = items
            default: throw fault("takes a list of texts in options, such as options = [\"a\", \"b\"].")
            }
            if type.kind == .choice, options.isEmpty { throw fault("is a choice, so it needs options, such as options = [\"a\", \"b\"].") }
            var defaultValue: String?
            switch fields["default"] {
            case nil: break
            case .string(let text): defaultValue = text
            case .integer(let number): defaultValue = String(number)
            case .number(let number): defaultValue = String(number)
            case .boolean(let flag): defaultValue = String(flag)
            default: throw fault("takes one value in default.")
            }
            if let defaultValue, type.isList || !type.accepts(defaultValue, options: options) {
                throw fault("has a default that is not \(type.isList ? "one value" : type.article): \(defaultValue).")
            }
            var pattern: AnswerPattern?
            if let text = try text("pattern") {
                guard type == ValueType(.url) || type == ValueType(.text) else { throw fault("has a pattern, which only a url or a text takes.") }
                guard let parsed = AnswerPattern(text) else { throw fault("has a pattern that is not a regular expression: \(text).") }
                pattern = parsed
            }
            self.name = name
            self.type = type
            self.isRequired = isRequired
            self.defaultValue = defaultValue
            self.pattern = pattern
            self.title = try text("title")
            self.icon = try text("icon")
            self.detail = try text("description")
            self.options = options
        }

        init(name: String, type: ValueType, isRequired: Bool = true, options: [String] = []) {
            self.name = name
            self.type = type
            self.isRequired = isRequired
            defaultValue = nil
            title = nil
            icon = nil
            detail = nil
            self.options = options
            pattern = nil
        }

        func fault(in values: [String]) -> String? {
            if !type.isList, values.count > 1 { return "\(name) takes one value, and got \(values.count)" }
            if let wrong = values.first(where: { !type.accepts($0, options: options) }) {
                return "\(name) takes \(type.article), and got \(wrong.isEmpty ? "an empty text" : wrong)"
            }
            guard let pattern, let wrong = values.first(where: { !pattern.matches($0) }) else { return nil }
            return "\(name) takes a value that matches \(pattern.text), and got \(wrong)"
        }
    }
}
