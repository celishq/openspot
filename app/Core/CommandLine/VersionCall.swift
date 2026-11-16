import Foundation

enum VersionCall: NounCall {
    case text

    static let noun = CommandNoun("version", group: .start, flags: ["--version"], verbs: [
        CommandVerb("", "", "Prints the version of Openspot, as --version does.") { $0.none ? Self.text : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        { CommandAnswer(output: (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown") + "\n") }
    }
}
