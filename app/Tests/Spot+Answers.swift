import Foundation
@testable import OpenspotCore

@MainActor
extension Spot {
    private func output(_ action: SpotAction, input: String? = nil, variables: [String: String] = [:], timeout: TimeInterval) async throws -> SpotOutput {
        SpotOutput(text: try await SpotRuns().answer(of: self, action, input: input, limit: timeout, variables: variables))
    }

    func state(timeout: TimeInterval) async throws -> SpotState {
        guard readsState else { return headerState }
        return try state(of: try await output(.read, timeout: timeout))
    }

    func opened(timeout: TimeInterval) async throws -> (spot: Spot, state: SpotState) {
        guard readsState else { return (self, headerState) }
        let output = try await output(.read, timeout: timeout)
        return (taking(output), try state(of: output))
    }

    func items(query: String = "", input: String? = nil, page: String? = nil, timeout: TimeInterval) async throws -> SpotOutput {
        let typed = query.isEmpty ? nil : TextBlock(fields: [.init(key: "search", value: query)]).text
        let lines = [input, typed].compactMap { $0 }
        let reason = query.isEmpty ? [:] : ReadReason.text(query, inSheet: answers == nil).variables
        let variables = reason.merging(page.map { ["OPENSPOT_PAGE": $0] } ?? [:]) { _, new in new }
        return try await output(.read, input: lines.isEmpty ? nil : lines.joined(), variables: variables, timeout: timeout)
    }

    func form(_ action: CommandAction, item: SpotItem?, timeout: TimeInterval) async throws -> ItemForm {
        guard let form = ItemForm(output: try await output(.action(action, item: item), timeout: timeout)) else { throw SpotError.badForm }
        return form
    }

    func submit(_ action: CommandAction, item: SpotItem?, draft: FormDraft, timeout: TimeInterval) async throws -> String {
        let text = try await SpotRuns().answer(of: self, .action(action, item: item), input: draft.text, limit: timeout)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    func perform(_ action: SpotAction, input: String? = nil, timeout: TimeInterval) async throws -> String? {
        try await output(action, input: input, timeout: timeout).summary?.value("toast")
    }

    func hook(_ function: String, card: String, origin: String) async -> Bool {
        let runs = SpotRuns()
        let answer = await withCheckedContinuation { continuation in
            if let now = runs.ask(function, of: self, card: card, origin: origin, later: { continuation.resume(returning: $0) }) {
                continuation.resume(returning: now)
            }
        }
        withExtendedLifetime(runs) {}
        return answer
    }

    func read(timeout: TimeInterval) async throws -> MetricValue {
        guard let value = MetricValue(output: try await output(.read, timeout: timeout)) else { throw SpotError.badMetric }
        return value
    }
}

extension ScanResult {
    var metrics: [Spot] {
        scripts.filter { $0.read?.seconds != nil }
    }
}
