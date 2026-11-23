import Foundation

struct FieldValues: Equatable, Sendable {
    static let hidden = "•••"

    let settings: [TextBlock.Field]
    let secrets: [String]

    init(of spot: Spot, in settings: [String: [String: String]], secrets kept: [String: String]) {
        let plain = settings[spot.id] ?? [:]
        var lines: [TextBlock.Field] = []
        var secrets: [String] = []
        for field in spot.settings {
            let value = field.isSecret ? kept[field.id] : plain[field.id].flatMap { $0.isEmpty ? nil : $0 } ?? field.defaultValue
            guard let value, !value.isEmpty else { continue }
            if field.isSecret {
                secrets.append(value)
                continue
            }
            lines.append(.init(key: field.id, value: value))
        }
        self.settings = lines
        self.secrets = secrets
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
