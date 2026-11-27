import Foundation

public struct SpotUseCall: Equatable, Sendable {
    public let use: SpotUse
    public let name: String
    public let words: String

    init?(name: String, rule: CallRule) {
        guard let use = rule.use else { return nil }
        self.use = use
        self.name = name.split(separator: " ").prefix(2).joined(separator: ".")
        words = rule.used
    }

    public init?(arguments: [String], of spot: String) {
        if let call = CommandLineCall(arguments: arguments, spot: spot), !call.isFault {
            guard let use = call.use else { return nil }
            self = use
        } else {
            guard let found = CommandLineCall.looseRule(of: arguments, spot: spot) else { return nil }
            self.init(name: found.name, rule: found.rule)
        }
    }
}
