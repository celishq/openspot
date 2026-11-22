import Foundation

extension SpotRuns {
    func run(_ name: String, of binding: Manifest.Binding, inputs given: [TextBlock.Field], from caller: SpotCaller) async -> RunEnd {
        let spot = caller.spot
        guard let sheet = sheets[binding.spot] else {
            return .failed("\(spot.name) binds \(binding.name) to the spot \(binding.spot), which is not installed. Install \(binding.spot), or remove \(binding.name) from the [bindings] of its spot.toml.")
        }
        let bound = sheet.spot
        guard let action = bound.typedActions.first(where: { $0.id == name }) else {
            let names = bound.typedActions.map(\.id)
            return .refused("\(bound.name) has no action \(name). " + (names.isEmpty ? "It declares no [actions]." : "Name one of its [actions]: \(names.joined(separator: ", "))."))
        }
        if let unknown = given.first(where: { field in !action.inputs.contains { $0.name == field.key } }) {
            return .refused("\(name) has no input \(unknown.key). Its inputs are: \(action.inputs.map(\.name).joined(separator: ", ")).")
        }
        let inputs: [TextBlock.Field]
        do {
            inputs = try action.inputs(given)
        } catch {
            return .refused(Self.reason(error))
        }
        let call = caller.call?.request
        let chain = (call?.chain ?? []) + [spot.id]
        let frame: Frame?
        do {
            frame = try await sheet.answer(to: Message(.press(name), inputs: inputs), key: "run:\(UUID().uuidString)", chain: chain, isPressed: call?.isByPerson ?? false)
        } catch {
            return .failed(Self.reason(error))
        }
        guard let frame else { return .unanswered("\(binding.name).\(name) stopped before it answered.") }
        if !frame.outputs.isEmpty { return .values(frame.outputs) }
        return action.outputs.isEmpty ? .values([]) : .unanswered("\(binding.name).\(name) answered with no values.")
    }

    static func reason(_ error: Error) -> String {
        (error as? SpotError)?.reason ?? error.localizedDescription
    }
}
