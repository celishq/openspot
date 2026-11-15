import Foundation

struct FieldValues: Equatable, Sendable {
    static let variablePrefix = "OPENSPOT_SETTING_"
    static let inputPrefix = "setting."
    static let hidden = "•••"

    let variables: [String: String]
    let input: String
    let secrets: [String]

    init(of spot: Spot, in settings: [String: [String: String]], secrets kept: [String: String]) {
        let plain = settings[spot.id] ?? [:]
        var variables: [String: String] = [:]
        var lines: [TextBlock.Field] = []
        var secrets: [String] = []
        for field in spot.settings {
            if field.isSecret {
                guard let value = kept[field.id], !value.isEmpty else { continue }
                lines.append(.init(key: Self.inputPrefix + field.id, value: value))
                secrets.append(value)
            } else if let value = plain[field.id], !value.isEmpty, value.utf8.count <= SpotAction.argumentLimit {
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

    func hiding(_ error: Error) -> Error {
        guard !secrets.isEmpty else { return error }
        return switch error as? SpotError {
        case .failed(let code, let message): SpotError.failed(code, hiding(message))
        case .failedWithFix(let code, let message, let fix): SpotError.failedWithFix(code, hiding(message), fix)
        case .fault(let message): SpotError.fault(hiding(message))
        case let error?: error
        case nil: SpotError.fault(hiding(error.localizedDescription))
        }
    }
}
