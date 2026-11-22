import Foundation

enum RunCall: NounCall {
    case run(binding: String, action: String, inputs: [TextBlock.Field])

    static let noun = CommandNoun("run", group: .build, verbs: [
        CommandVerb(
            "", "<binding>.<action> [<name>=<value>...]",
            "Runs an action of a spot that the [bindings] of the calling spot names, with its inputs checked, and prints its out.<name> lines. It runs only in a run of a spot."
        ) { words in
            guard let target = words.rest.first else { return nil }
            guard let dot = target.firstIndex(of: "."), dot != target.startIndex, target.index(after: dot) != target.endIndex else {
                return CallFault.refused("`\(target)` names no action of a binding. Write <binding>.<action>, such as picker.pick.")
            }
            var inputs: [TextBlock.Field] = []
            for word in words.rest.dropFirst() {
                guard let equals = word.firstIndex(of: "="), equals != word.startIndex else {
                    return CallFault.refused("\(word) is not an input. Write <name>=<value>, such as url=https://example.com.")
                }
                inputs.append(.init(key: String(word[..<equals]), value: String(word[word.index(after: equals)...])))
            }
            return Self.run(binding: String(target[..<dot]), action: String(target[target.index(after: dot)...]), inputs: inputs)
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard case .run(let name, let action, let inputs) = self else { return nil }
        guard let runs = context.runs, let caller = context.request.caller, context.caller != nil else {
            return { CommandAnswer(errors: "`openspot run` runs only in a run of a spot, since it calls a spot that the spot binds.\n", code: 2) }
        }
        let spot = caller.spot
        guard let binding = spot.bindings.first(where: { $0.name == name }) else {
            return { CommandAnswer(errors: "\(spot.name) has no binding \(name). Add it to the [bindings] of its spot.toml, such as \(name) = { spot = \"<id>\" }.\n", code: 2) }
        }
        return {
            let end = await runs.run(action, of: binding, inputs: inputs, from: caller)
            switch end {
            case .values(let values):
                return CommandAnswer(output: TextBlock(fields: values.map { .init(key: "\(RootKey.outputPrefix)\($0.key)", value: $0.value) }).text)
            case .failed(let line), .refused(let line), .unanswered(let line):
                return CommandAnswer(errors: line + "\n", code: end.code)
            case .cancelled:
                return CommandAnswer(code: end.code)
            }
        }
    }
}
