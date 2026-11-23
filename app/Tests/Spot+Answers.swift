import Foundation
@testable import OpenspotCore

@MainActor
extension Spot {
    private func output(_ action: SpotWords, input: String? = nil, timeout: TimeInterval) async throws -> Frame {
        let message = (input ?? "") + TestSettings.text
        return Frame(text: try await SpotRuns(environment: TestEnvironment.values).answer(of: self, action, input: message.isEmpty ? nil : message, limit: timeout), kinds: self.kinds)
    }

    func state(timeout: TimeInterval) async throws -> SpotState {
        guard showsState else { return headerState }
        return try state(of: try await output(.show, timeout: timeout))
    }

    func opened(timeout: TimeInterval) async throws -> (spot: Spot, state: SpotState) {
        guard showsState else { return (self, headerState) }
        let output = try await output(.show, timeout: timeout)
        return (taking(output), try state(of: output))
    }

    func items(query: String = "", input: String? = nil, page: String? = nil, timeout: TimeInterval) async throws -> Frame {
        var message = query.isEmpty ? Message(.show) : ShowEvent.typed(query, inSheet: self.triggers.search == nil).message()
        if let page { message.inputs.append(.init(key: "route", value: page)) }
        message.given = input
        let text = message.text
        return try await output(message.words, input: text?.isEmpty == true ? nil : text, timeout: timeout)
    }

    func answer(_ action: SpotWords, input: String? = nil, timeout: TimeInterval) async throws -> Frame {
        try await output(action, input: input, timeout: timeout)
    }

    func sheetFaults(timeout: TimeInterval) async throws -> [String] {
        FrameCheck(text: try await SpotRuns(environment: TestEnvironment.values).answer(of: self, .show, limit: timeout)).sheetFaults
    }

    private func message(_ action: CommandAction, item: SpotItem?, inputs: [TextBlock.Field] = []) -> Message {
        let call = SpotWords.action(action, item: item)
        guard call.arguments.count > 1 else { return Message(call, inputs: inputs) }
        return Message(.press(call.arguments[0]), inputs: [.init(key: "item", value: call.arguments[1])] + inputs)
    }

    func form(_ action: CommandAction, item: SpotItem?, timeout: TimeInterval) async throws -> ItemForm {
        if let typed = self.typedActions.first(where: { $0.id == action.id }), typed.lacksInput {
            guard let form = ItemForm(output: Frame(text: typed.form(with: [:], title: action.title))) else { throw SpotError.badForm }
            return form
        }
        let message = message(action, item: item)
        guard let form = ItemForm(output: try await output(message.words, input: message.text, timeout: timeout)) else { throw SpotError.badForm }
        return form
    }

    func submit(_ action: CommandAction, item: SpotItem?, draft: FormDraft, timeout: TimeInterval) async throws {
        let message = message(action, item: item, inputs: draft.inputs)
        _ = try await output(message.words, input: message.text, timeout: timeout)
    }

    func perform(_ action: SpotWords, input: String? = nil, page: String? = nil, timeout: TimeInterval) async throws {
        let route = page.map { "input.route=\($0)\n" } ?? ""
        _ = try await output(action, input: route + (input ?? ""), timeout: timeout)
    }

    func hook(_ handler: String, card: String, origin: String) async -> Bool {
        let runs = SpotRuns(environment: TestEnvironment.values)
        let answer = await withCheckedContinuation { continuation in
            if let now = runs.answer(handler, of: self, card: card, origin: origin, later: { continuation.resume(returning: !$0.isEmpty) }) {
                continuation.resume(returning: !now.isEmpty)
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
        scripts.filter { $0.triggers.every != nil }
    }
}
