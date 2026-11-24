import Foundation

enum FrontCall: NounCall {
    case app

    static let noun = CommandNoun("front", group: .mac, verbs: [
        CommandVerb("app", "", "Prints the app= bundle ID, name= and path= of the app in front of Openspot, or nothing.", rule: ReadSources.rule) { $0.none ? Self.app : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        ReadSources.work(in: context) { sources, _ in await sources.front() }
    }
}
