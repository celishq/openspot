import Foundation

enum AttachmentCall: NounCall {
    case add([String])
    case empty(String)

    private static let rule = CallRule(use: .attachment, used: "put a value in the panel's field", flags: .needsApp)

    static let noun = CommandNoun("attachment", group: .build, verbs: [
        CommandVerb(
            "add", "[input...]",
            "Puts a value in the panel's field, where people press Tab to hand it to a spot that takes its kind: `file=` once for each file, `url=` or `text=`, with `title=` and the bundle ID of its app in `app=`. With no input it takes the record on stdin that `openspot browser tab` prints, and adds nothing when it holds no value. It works in a show.",
            rule: rule
        ) { words in Self.add(words.rest) },
        CommandVerb(
            "empty", "<words>...",
            "Shows the words in the panel's field when the chip that Tab picks has nothing to hand over, such as Nothing selected in Finder. It works in a show.",
            rule: rule
        ) { words in words.none ? nil : Self.empty(words.rest.joined(separator: " ")) }
    ])

    static let oneKind = "`openspot attachment add` takes one kind of value: file= once for each file, url= or text=."

    func rule(_ rule: CallRule, spot: String?) -> CallRule {
        guard case .add(let words) = self, words.isEmpty else { return rule }
        var rule = rule
        rule.flags.insert(.readsInput)
        return rule
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard let runs = context.runs else { return CommandAnswer.notRunning("attachment") }
        guard let caller = context.request.caller else {
            let verb = if case .empty = self { "empty" } else { "add" }
            return { CommandAnswer(errors: "`openspot attachment \(verb)` runs only from a spot, since its value shows as that spot's chip.\n", code: 1) }
        }
        switch self {
        case .add(let words): return add(words, to: runs, from: caller, input: context.input)
        case .empty(let words):
            return {
                _ = await runs.take(SpotEffect.attachment(.empty(words)), from: caller)
                return CommandAnswer()
            }
        }
    }

    private func add(_ words: [String], to runs: SpotRuns, from caller: SpotCaller, input: @escaping @Sendable () async -> String) -> CommandAPI.Work {
        guard words.isEmpty else {
            var fields: [TextBlock.Field] = []
            for word in words {
                guard let split = word.firstIndex(of: "="), Self.keys.contains(String(word[..<split])) else {
                    return { CommandAnswer(errors: "`openspot attachment add` does not take \(word). Write file=, url= or text=, and title= or app=.\n", code: 2) }
                }
                fields.append(TextBlock.Field(key: String(word[..<split]), value: String(word[word.index(after: split)...])))
            }
            return Self.add(fields, to: runs, from: caller)
        }
        return {
            let fields = (TextBlock.blocks(in: await input()).first?.fields ?? []).filter { Self.keys.contains($0.key) }
            guard fields.contains(where: { !Self.notes.contains($0.key) }) else { return CommandAnswer() }
            return await Self.add(fields, to: runs, from: caller)()
        }
    }

    private static let notes = ["title", "app"]
    private static let keys = ["file", "url", "text"] + notes

    private static func add(_ fields: [TextBlock.Field], to runs: SpotRuns, from caller: SpotCaller) -> CommandAPI.Work {
        let kinds = Set(fields.map(\.key).filter { !notes.contains($0) })
        let title = fields.last { $0.key == "title" }?.value
        let app = fields.last { $0.key == "app" }?.value
        let values = fields.filter { kinds.contains($0.key) }.map(\.value)
        guard kinds.count == 1, let kind = kinds.first, kind == "file" || values.count == 1 else {
            return { CommandAnswer(errors: "\(oneKind)\n", code: 2) }
        }
        return {
            let value = switch kind {
            case "url": AttachmentValue(url: values[0], title: title, app: app)
            case "text": AttachmentValue(text: values[0], title: title, app: app)
            default: AttachmentValue(files: FileKinds.Disk().read(values), title: title, app: app)
            }
            _ = await runs.take(SpotEffect.attachment(.ready(value)), from: caller)
            return CommandAnswer()
        }
    }
}
