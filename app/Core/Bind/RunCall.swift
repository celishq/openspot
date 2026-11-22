import Foundation

enum RunCall: NounCall {
    case run(binding: String, action: String, inputs: [TextBlock.Field], out: String?, stdin: String?)

    static let channelOnly = "runs only in a run of a spot, through the channel that Openspot gives it on descriptor 11."
    private static let outWord = "--out"
    private static let stdinWord = "--stdin"

    static let noun = CommandNoun("run", group: .build, verbs: [
        CommandVerb(
            "", "<binding>.<action> [<name>=<value>...] [--out <name>] [--stdin <name>]",
            "Runs an action of a spot that the [bindings] of the calling spot names, with its inputs checked, and waits for its values. It prints the out.<name> lines, or one value with --out. --stdin reads that input from stdin. An action that answers with a view shows it over the sheet until a press in it gives values; a close of it exits 4. It runs only in a run of a spot.",
            rule: CallRule(flags: .readsInput)
        ) { words in parse(words.rest) }
    ])

    private static func parse(_ words: [String]) -> (any NounCall)? {
        var target: String?
        var inputs: [TextBlock.Field] = []
        var out: String?
        var stdin: String?
        var index = 0
        while index < words.count {
            let word = words[index]
            index += 1
            if word == outWord || word == stdinWord {
                guard index < words.count else { return nil }
                if word == outWord { out = words[index] } else { stdin = words[index] }
                index += 1
            } else if target == nil {
                target = word
            } else {
                guard let equals = word.firstIndex(of: "="), equals != word.startIndex else {
                    return CallFault.refused("\(word) is not an input. Write <name>=<value>, such as url=https://example.com.")
                }
                inputs.append(.init(key: String(word[..<equals]), value: String(word[word.index(after: equals)...])))
            }
        }
        guard let target else { return nil }
        guard let dot = target.firstIndex(of: "."), dot != target.startIndex, target.index(after: dot) != target.endIndex else {
            return CallFault.refused("`\(target)` names no action of a binding. Write <binding>.<action>, such as picker.pick.")
        }
        return Self.run(binding: String(target[..<dot]), action: String(target[target.index(after: dot)...]), inputs: inputs, out: out, stdin: stdin)
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard case .run(let name, let action, let inputs, let out, let stdin) = self else { return nil }
        guard let runs = context.runs, let caller = context.request.caller, context.channel != nil else {
            return { CommandAnswer(errors: "`openspot run` \(Self.channelOnly)\n", code: 2) }
        }
        let spot = caller.spot
        guard let binding = spot.bindings.first(where: { $0.name == name }) else {
            return { CommandAnswer(errors: "\(spot.name) has no binding \(name). Add it to the [bindings] of its spot.toml, such as \(name) = { spot = \"<id>\" }.\n", code: 2) }
        }
        let run = BoundRun(binding: binding, action: action, inputs: inputs, out: out, stdin: stdin.map { name in (name, context.input) })
        return { [app = context.app] in
            let end = await runs.run(run, from: caller, app: app)
            switch end {
            case .values(let values):
                let output = out.map { name in values.filter { $0.key == name }.map { $0.value + "\n" }.joined() }
                return CommandAnswer(output: output ?? TextBlock(fields: values.map { .init(key: "\(RootKey.outputPrefix)\($0.key)", value: $0.value) }).text)
            case .failed(let line), .refused(let line), .unanswered(let line):
                return CommandAnswer(errors: line + "\n", code: end.code)
            case .cancelled:
                return CommandAnswer(code: end.code)
            }
        }
    }
}
