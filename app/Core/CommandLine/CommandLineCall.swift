import Foundation

public struct CommandLineCall: Equatable, Sendable {
    public let name: String
    public let rule: CallRule
    let call: any NounCall

    public var value: any Equatable & Sendable {
        call
    }

    public var isFault: Bool {
        call is CallFault
    }

    public static let usage = usage(of: CommandNoun.all)

    static func usage(of nouns: [CommandNoun]) -> String {
        let guides = CommandNoun.listed(nouns.filter { $0.guide != nil }.map(\.name).sorted())
        return nouns.flatMap { $0.lines(guides: guides) }.map { $0 + "\n" }.joined()
    }

    init(name: String, rule: CallRule = CallRule(), call: any NounCall) {
        self.name = name
        self.rule = rule
        self.call = call
    }

    public init?(arguments: [String], spot: String? = nil, reason: String? = nil, nouns: [CommandNoun] = CommandNoun.all) {
        guard let first = arguments.first, first == HelpCall.flag || !first.hasPrefix("-") else { return nil }
        let noun = first == HelpCall.flag && arguments.count == 1 ? HelpCall.noun.name : first
        let spot = spot?.isEmpty == true ? nil : spot
        let rest = Array(arguments.dropFirst())
        let unknown = CommandLineCall(name: noun, call: CallFault.unknown(arguments.joined(separator: " ")))
        guard let found = nouns.first(where: { $0.name == noun }), let verb = found.verb(of: rest),
              let call = verb.parse(CallWords(rest: Array(rest.dropFirst(verb.words.count)), spot: spot, reason: reason))
        else {
            self = unknown
            return
        }
        let name = ([noun] + verb.words).joined(separator: " ")
        guard !(call is CallFault) else {
            self.init(name: name, call: call)
            return
        }
        let rule = call.rule(verb.rule, spot: spot)
        if reason != nil, let refusal = rule.refusal(of: name) {
            self.init(name: name, call: CallFault.refused(refusal))
            return
        }
        self.init(name: name, rule: rule, call: call)
    }

    static func looseRule(of arguments: [String], spot: String, nouns: [CommandNoun] = CommandNoun.all) -> (name: String, rule: CallRule)? {
        let rest = Array(arguments.dropFirst())
        guard let noun = nouns.first(where: { $0.name == arguments.first }), let verb = noun.verb(of: rest) else { return nil }
        let rule = noun.loose?(verb, Array(rest.dropFirst(verb.words.count)), spot) ?? verb.rule
        return (([noun.name] + verb.words).joined(separator: " "), rule)
    }

    var use: SpotUseCall? {
        SpotUseCall(name: name, rule: rule)
    }

    public static func == (lhs: CommandLineCall, rhs: CommandLineCall) -> Bool {
        lhs.name == rhs.name && lhs.rule == rhs.rule && lhs.call.isSame(as: rhs.call)
    }
}
