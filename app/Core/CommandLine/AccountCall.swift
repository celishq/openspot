import Foundation

public enum AccountCall: Equatable, Sendable {
    case status(frame: Bool)
    case sync(Bool)
    case new(String?)
    case words
    case checked
    case phrase
    case signIn
    case signOut

    init?(_ words: [String]) {
        switch (words.first, words.count) {
        case (nil, _): self = .status(frame: false)
        case ("--frame", 1): self = .status(frame: true)
        case ("new", _):
            let handle = words.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces)
            self = .new(handle.isEmpty ? nil : handle)
        case ("words", 1): self = .words
        case ("checked", 1): self = .checked
        case ("phrase", 1): self = .phrase
        case ("sign-in", 1): self = .signIn
        case ("sign-out", 1): self = .signOut
        case ("sync", 2) where words[1] == "on" || words[1] == "off": self = .sync(words[1] == "on")
        default: return nil
        }
    }

    var name: String {
        switch self {
        case .status: "account"
        case .sync: "account sync"
        case .new: "account new"
        case .words: "account words"
        case .checked: "account checked"
        case .phrase: "account phrase"
        case .signIn: "account sign-in"
        case .signOut: "account sign-out"
        }
    }

    var change: (name: String, act: String)? {
        switch self {
        case .new: ("openspot \(name)", "makes an account")
        case .checked, .signIn, .signOut: ("openspot \(name)", "changes your account")
        case .sync: ("openspot \(name)", "changes where your account is kept")
        case .status, .words, .phrase: nil
        }
    }

    var reachesKey: Bool {
        if case .status = self { false } else { true }
    }
}
