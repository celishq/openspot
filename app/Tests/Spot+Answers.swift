import Foundation
@testable import OpenspotCore

@MainActor
extension Spot {
    private func output(_ action: SpotAction, input: String? = nil, timeout: TimeInterval) async throws -> SpotOutput {
        let message = (input ?? "") + TestSettings.text
        return SpotOutput(text: try await SpotRuns(environment: TestEnvironment.values).answer(of: self, action, input: message.isEmpty ? nil : message, limit: timeout))
    }

    func state(timeout: TimeInterval) async throws -> SpotState {
        guard readsState else { return headerState }
        return try state(of: try await output(.show, timeout: timeout))
    }

    func opened(timeout: TimeInterval) async throws -> (spot: Spot, state: SpotState) {
        guard readsState else { return (self, headerState) }
        let output = try await output(.show, timeout: timeout)
        return (taking(output), try state(of: output))
    }

    func items(query: String = "", input: String? = nil, page: String? = nil, timeout: TimeInterval) async throws -> SpotOutput {
        let event = query.isEmpty ? [] : ReadReason.text(query, inSheet: self.answers == nil).fields
        let route = page.map { [TextBlock.Field(key: "route", value: $0)] } ?? []
        let typed = query.isEmpty ? [] : [TextBlock.Field(key: "search", value: query)]
        let message = TextBlock(fields: event + route + typed).text + (input ?? "")
        return try await output(.show, input: message.isEmpty ? nil : message, timeout: timeout)
    }

    func answer(_ action: SpotAction, input: String? = nil, timeout: TimeInterval) async throws -> SpotOutput {
        try await output(action, input: input, timeout: timeout)
    }

    func sheetFaults(timeout: TimeInterval) async throws -> [String] {
        FrameCheck(text: try await SpotRuns(environment: TestEnvironment.values).answer(of: self, .show, limit: timeout)).sheetFaults
    }

    func form(_ action: CommandAction, item: SpotItem?, timeout: TimeInterval) async throws -> ItemForm {
        guard let form = ItemForm(output: try await output(.action(action, item: item), timeout: timeout)) else { throw SpotError.badForm }
        return form
    }

    func submit(_ action: CommandAction, item: SpotItem?, draft: FormDraft, timeout: TimeInterval) async throws -> String {
        try await output(.action(action, item: item), input: draft.text, timeout: timeout).select ?? ""
    }

    @discardableResult
    func perform(_ action: SpotAction, input: String? = nil, page: String? = nil, timeout: TimeInterval) async throws -> String? {
        let route = page.map { "route=\($0)\n" } ?? ""
        return try await output(action, input: route + (input ?? ""), timeout: timeout).summary?.value("toast")
    }

    func hook(_ function: String, card: String, origin: String) async -> Bool {
        let runs = SpotRuns(environment: TestEnvironment.values)
        let answer = await withCheckedContinuation { continuation in
            if let now = runs.answer(function, of: self, card: card, origin: origin, later: { continuation.resume(returning: !$0.isEmpty) }) {
                continuation.resume(returning: !now.isEmpty)
            }
        }
        withExtendedLifetime(runs) {}
        return answer
    }

    func hotkey(_ function: String, card: String, origin: String) async -> String {
        let runs = SpotRuns(environment: TestEnvironment.values)
        let answer = await withCheckedContinuation { continuation in
            if let now = runs.answer(function, of: self, card: card, origin: origin, later: { continuation.resume(returning: $0) }) {
                continuation.resume(returning: now)
            }
        }
        withExtendedLifetime(runs) {}
        return answer
    }

    func read(timeout: TimeInterval) async throws -> MetricValue {
        guard let value = MetricValue(output: try await output(.show, timeout: timeout)) else { throw SpotError.badMetric }
        return value
    }
}

extension ScanResult {
    var metrics: [Spot] {
        scripts.filter { $0.read?.seconds != nil }
    }
}
