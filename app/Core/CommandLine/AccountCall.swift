import Foundation

public enum AccountCall: Equatable, Sendable {
    case status(frame: Bool)
    case sync(Bool)
    case new
    case words
    case check([Int])
    case checked
    case phrase
    case signIn
    case signOut

    init?(_ words: [String]) {
        switch (words.first, words.count) {
        case (nil, _): self = .status(frame: false)
        case ("--frame", 1): self = .status(frame: true)
        case ("new", 1): self = .new
        case ("words", 1): self = .words
        case ("check", 2...):
            let places = words.dropFirst().compactMap { Int($0) }.filter { (1...AccountPhrase.wordCount).contains($0) }
            guard places.count == words.count - 1 else { return nil }
            self = .check(places)
        case ("checked", 1): self = .checked
        case ("phrase", 1): self = .phrase
        case ("sign-in", 1): self = .signIn
        case ("sign-out", 1): self = .signOut
        case ("sync", 2) where words[1] == "on" || words[1] == "off": self = .sync(words[1] == "on")
        default: return nil
        }
    }

    var change: (name: String, act: String)? {
        switch self {
        case .new: ("openspot account new", "makes an account")
        case .checked: ("openspot account checked", "changes your account")
        case .signIn: ("openspot account sign-in", "changes your account")
        case .signOut: ("openspot account sign-out", "changes your account")
        case .sync: ("openspot account sync", "changes where your account is kept")
        case .status, .words, .check, .phrase: nil
        }
    }

    var reachesKey: Bool {
        if case .status = self { false } else { true }
    }
}
