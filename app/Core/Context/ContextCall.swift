import Foundation

enum ContextCall: NounCall {
    case add([String])

    static let noun = CommandNoun("context", group: .build, verbs: [
        CommandVerb(
            "add", "[input...]",
            "Puts a value in the panel's field, where people press Tab to hand it to a spot that takes its kind: `file=` once for each file, `url=` or `text=`, with `title=` and the bundle ID of its app in `app=`. It works in a show.",
            rule: CallRule(use: .context, used: "put a value in the panel's field", flags: .needsApp)
        ) { words in Self.add(words.rest) }
    ])

    static let oneKind = "`openspot context add` takes one kind of value: file= once for each file, url= or text=."

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard case .add(let words) = self else { return nil }
        guard let runs = context.runs else { return CommandAnswer.notRunning("context") }
        guard let caller = context.request.caller else {
            return { CommandAnswer(errors: "`openspot context add` runs only from a spot, since its value shows as that spot's chip.\n", code: 1) }
        }
        var fields: [(key: String, value: String)] = []
        for word in words {
            guard let split = word.firstIndex(of: "="), ["file", "url", "text", "title", "app"].contains(String(word[..<split])) else {
                return { CommandAnswer(errors: "`openspot context add` does not take \(word). Write file=, url= or text=, and title= or app=.\n", code: 2) }
            }
            fields.append((String(word[..<split]), String(word[word.index(after: split)...])))
        }
        let kinds = Set(fields.map(\.key).filter { $0 != "title" && $0 != "app" })
        let title = fields.last { $0.key == "title" }?.value
        let app = fields.last { $0.key == "app" }?.value
        let values = fields.filter { kinds.contains($0.key) }.map(\.value)
        guard kinds.count == 1, let kind = kinds.first, kind == "file" || values.count == 1 else {
            return { CommandAnswer(errors: "\(Self.oneKind)\n", code: 2) }
        }
        return {
            let value = switch kind {
            case "url": ContextValue(url: values[0], title: title, app: app)
            case "text": ContextValue(text: values[0], title: title, app: app)
            default: ContextValue(files: FileKinds.Disk().read(values), title: title, app: app)
            }
            _ = await runs.take(SpotEffect.context(value), from: caller)
            return CommandAnswer()
        }
    }
}
