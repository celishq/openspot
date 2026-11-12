import Foundation
@testable import OpenspotCore

/// One call of a script through the owner of all runs, for a test that proves what a script answers.
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

    func items(query: String = "", input: String? = nil, timeout: TimeInterval) async throws -> SpotOutput {
        let typed = query.isEmpty ? nil : TextBlock(fields: [.init(key: "search", value: query)]).text
        let lines = [input, typed].compactMap { $0 }
        let reason = query.isEmpty ? [:] : ReadReason.text(query, inSheet: answers == nil).variables
        return try await output(.read, input: lines.isEmpty ? nil : lines.joined(), variables: reason, timeout: timeout)
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

    func read(timeout: TimeInterval) async throws -> MetricValue {
        guard let value = MetricValue(output: try await output(.read, timeout: timeout)) else { throw SpotError.badMetric }
        return value
    }
}

extension ScanResult {
    /// The scripts with a number in their `read`.
    var metrics: [Spot] {
        scripts.filter { $0.read?.seconds != nil }
    }
}
