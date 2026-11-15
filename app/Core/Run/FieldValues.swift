import Foundation

struct FieldValues: Equatable, Sendable {
    static let variablePrefix = "OPENSPOT_SETTING_"
    static let inputPrefix = "setting."
    static let hidden = "•••"

    let variables: [String: String]
    let input: String
    let secrets: [String]

    init(of spot: Spot, in settings: [String: [String: String]]) {
        let kept = settings[spot.id] ?? [:]
        var variables: [String: String] = [:]
        var lines: [TextBlock.Field] = []
        var secrets: [String] = []
        for field in spot.settings {
            guard let value = kept[field.id], !value.isEmpty else { continue }
            if field.isSecret {
                lines.append(.init(key: Self.inputPrefix + field.id, value: value))
                secrets.append(value)
            } else {
                variables[Self.variable(of: field.id)] = value
            }
        }
        self.variables = variables
        input = TextBlock(fields: lines).text
        self.secrets = secrets
    }

    static func variable(of key: String) -> String {
        variablePrefix + String(key.uppercased().map { $0.isASCII && ($0.isLetter || $0.isNumber) ? $0 : "_" })
    }

    func input(with given: String?) -> String? {
        guard !input.isEmpty else { return given }
        guard let given, !given.isEmpty else { return input }
        return given + (given.hasSuffix("\n") ? "" : "\n") + input
    }

    func hiding(_ text: String) -> String {
        secrets.reduce(text) { $0.replacingOccurrences(of: $1, with: Self.hidden) }
    }

    func hiding(_ text: String?) -> String? {
        text.map(hiding)
    }
}
