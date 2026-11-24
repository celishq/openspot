import Foundation

enum AttachmentCall: NounCall {
    case add([String])

    private static let rule = CallRule(use: .attachment, used: "put a value in the panel's field", flags: .needsApp)

    static let noun = CommandNoun("attachment", group: .build, verbs: [
        CommandVerb(
            "add", "[input...]",
            "Puts a value in the panel's field, where people press Tab to hand it to a spot that takes its kind: `file=` once for each file, `url=` or `text=`, with `title=`, the app in `app=`, and the picture of its chip in `icon=`, as `icon` in spot.toml takes it. With no input it takes the record on stdin that `openspot browser tab` prints, and adds nothing when it holds no value. It works in a show.",
            rule: rule
        ) { words in Self.add(words.rest) }
    ])

    static let fileLimit = 1_000

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
            return { CommandAnswer(errors: "`openspot attachment add` runs only from a spot, since its value shows as that spot's chip.\n", code: 1) }
        }
        switch self {
        case .add(let words): return add(words, to: runs, from: caller, input: context.input)
        }
    }

    private func add(_ words: [String], to runs: SpotRuns, from caller: SpotCaller, input: @escaping @Sendable () async -> String) -> CommandAPI.Work {
        guard words.isEmpty else {
            var fields: [TextBlock.Field] = []
            for word in words {
                guard let split = word.firstIndex(of: "="), Self.keys.contains(String(word[..<split])) else {
                    return { CommandAnswer(errors: "`openspot attachment add` does not take \(word). Write file=, url= or text=, and title=, app= or icon=.\n", code: 2) }
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

    private static let notes = ["title", "app", "icon"]
    private static let keys = ["file", "url", "text"] + notes

    private static func add(_ fields: [TextBlock.Field], to runs: SpotRuns, from caller: SpotCaller) -> CommandAPI.Work {
        let kinds = Set(fields.map(\.key).filter { !notes.contains($0) })
        let title = fields.last { $0.key == "title" }?.value
        let app = fields.last { $0.key == "app" }?.value
        let icon = Icon(text: fields.last { $0.key == "icon" }?.value)
        let values = fields.filter { kinds.contains($0.key) }.map(\.value)
        guard kinds.count == 1, let kind = kinds.first, kind == "file" || values.count == 1 else {
            return { CommandAnswer(errors: "\(oneKind)\n", code: 2) }
        }
        let kept = kind == "file" ? Array(values.prefix(fileLimit)) : values.map(ReadSources.cut)
        return {
            let value = switch kind {
            case "url": AttachmentValue(url: kept[0], title: title, app: app, icon: icon)
            case "text": AttachmentValue(text: kept[0], title: title, app: app, icon: icon)
            default: AttachmentValue(files: FileKinds.Disk().read(kept), title: title, app: app, icon: icon)
            }
            _ = await runs.take(SpotEffect.attachment(value), from: caller)
            return CommandAnswer()
        }
    }
}
