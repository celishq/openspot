import Foundation

enum ReadCall: NounCall {
    case source(ReadSource)
    case access

    private static let rule = CallRule(use: .read, used: "read what the person works on", flags: .needsApp)

    static let noun = CommandNoun("read", group: .mac, verbs: [
        CommandVerb("tab", "", "Prints the url=, title= and app= of the front tab when a browser is in front, or nothing.", rule: rule) { $0.none ? Self.source(.tab) : nil },
        CommandVerb("finder", "", "Prints a file= for each file selected in Finder, and app=.", rule: rule) { $0.none ? Self.source(.finder) : nil },
        CommandVerb("selection", "", "Prints the text= selected in the front app, and its app=.", rule: rule) { $0.none ? Self.source(.selection) : nil },
        CommandVerb(
            "clipboard", "", "Prints the text= on the clipboard, or url= when it holds one link, and its age= in seconds since Openspot first saw that copy.", rule: rule
        ) { $0.none ? Self.source(.clipboard) : nil },
        CommandVerb(
            "--access", "", "Prints reader=, app= and access= for each reader: allowed, denied, unasked, or unknown while its app is closed.", rule: rule
        ) { $0.none ? Self.access : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let reads = context.mac.reads
        let asks = !context.isInShow
        return CommandAnswer.work { [self] in
            let sources = try Mac.part(reads, "reads")
            let records = switch self {
            case .source(let source): try await sources.read(source, asks: asks)
            case .access: await sources.access()
            }
            return records.map(\.text).joined(separator: "\n")
        }
    }
}
