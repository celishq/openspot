import Foundation

public enum CallFault: NounCall {
    case refused(String)
    case undeclared(UseRefusal)
    case unknown([String])

    func work(in context: CallContext) -> CommandAPI.Work? {
        switch self {
        case .refused(let line): { CommandAnswer(errors: "\(line)\n", code: 1) }
        case .undeclared(let refusal): { CommandAnswer(errors: refusal.lines, code: 1) }
        case .unknown(let words): { [nouns = context.nouns] in CommandAnswer(errors: CommandHelp(nouns: nouns).unknown(words), code: 2) }
        }
    }
}
