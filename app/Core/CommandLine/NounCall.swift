import Foundation

protocol NounCall: Equatable, Sendable {
    func work(in context: CallContext) -> CommandAPI.Work?
    func rule(_ rule: CallRule, spot: String?) -> CallRule
}

extension NounCall {
    func rule(_ rule: CallRule, spot: String?) -> CallRule {
        rule
    }

    func isSame(as other: any NounCall) -> Bool {
        other as? Self == self
    }
}
