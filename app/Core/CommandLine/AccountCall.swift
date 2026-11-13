import Foundation

/// A call of `openspot account`: the public facts, or a call that reaches the account key, which only Openspot's Account
/// spot may make (protocol: Trust).
public enum AccountCall: Equatable, Sendable {
    /// Prints the account as JSON, or with `frame` as one block.
    case status(frame: Bool)
    /// Makes the account sync through iCloud Keychain, or stay on this Mac.
    case sync(Bool)
    /// Makes a key when the Mac holds none.
    case new
    /// Prints the 12 words of the key, after Touch ID.
    case words
    /// Prints 4 choices for each of these places of the words, the same each time.
    case check([Int])
    /// Takes a place and a word on each line of stdin, and marks the words backed up when each is right.
    case checked
    /// Reads a phrase on stdin, and prints how far it is from an account.
    case phrase
    /// Keeps the key of the phrase or the nsec on stdin.
    case signIn
    /// Removes the key, after Touch ID.
    case signOut

    /// The call of these words after `account`, with what a call that changes the account does, for the refusal in a
    /// read, or nil for words that are no call.
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

    /// The name of the call and what it changes, which a read may not do, or nil for a call that changes nothing.
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

    /// Whether it reaches the account key: each call but the public facts.
    var reachesKey: Bool {
        if case .status = self { false } else { true }
    }
}
