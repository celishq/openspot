import Foundation

extension Manifest {
    public struct InputCheck: Equatable, Sendable {
        public enum Kind: Sendable {
            case input, value

            var word: String {
                switch self {
                case .input: "input"
                case .value: "value"
                }
            }

            var article: String {
                switch self {
                case .input: "an input"
                case .value: "a value"
                }
            }

            var failure: String {
                switch self {
                case .input: "cannot run"
                case .value: "cannot be sent"
                }
            }
        }

        let owner: String
        let kind: Kind
        let parameters: [Parameter]

        static func fields(of words: [String], as kind: Kind) throws -> [TextBlock.Field] {
            try words.map { word in
                guard let equals = word.firstIndex(of: "="), equals != word.startIndex else {
                    throw SpotError.fault("\(word) is not \(kind.article). Write <name>=<value>, such as url=https://example.com.")
                }
                return TextBlock.Field(key: String(word[..<equals]), value: String(word[word.index(after: equals)...]))
            }
        }

        func refuse(unknown names: [String]) throws {
            guard let unknown = names.first(where: { name in !parameters.contains { $0.name == name } }) else { return }
            throw SpotError.fault("\(owner) has no \(kind.word) \(unknown). Its \(kind.word)s are: \(parameters.map(\.name).joined(separator: ", ")).")
        }

        func checked(_ given: [TextBlock.Field], keepingUndeclared: Bool = false) throws -> [TextBlock.Field] {
            if !keepingUndeclared { try refuse(unknown: given.map(\.key)) }
            var checked: [TextBlock.Field] = []
            for parameter in parameters {
                var values = given.filter { $0.key == parameter.name && !$0.value.isEmpty }.map(\.value)
                if values.isEmpty, let defaultValue = parameter.defaultValue { values = [defaultValue] }
                if values.isEmpty {
                    if parameter.isRequired { throw SpotError.fault("\(owner) needs \(parameter.name), which is \(parameter.type.article).") }
                    continue
                }
                if let fault = parameter.fault(in: values) { throw SpotError.fault("\(owner) \(kind.failure): \(fault).") }
                checked += values.map { .init(key: parameter.name, value: $0) }
            }
            let names = Set(parameters.map(\.name))
            return checked + given.filter { !names.contains($0.key) }
        }
    }
}
