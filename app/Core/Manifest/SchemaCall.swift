import Foundation

enum SchemaCall: NounCall {
    case print

    static let noun = CommandNoun("schema", group: .build, verbs: [
        CommandVerb("", "", "Prints the JSON Schema of spot.toml, which an editor checks the file with.") { $0.none ? Self.print : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        { CommandAnswer(output: ManifestSchema.text) }
    }
}
