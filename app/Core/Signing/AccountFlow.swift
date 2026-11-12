import Foundation
import Observation

/// The steps of the account sheet: choose between a new account and an existing one, read what the 12 words are, see
/// them, prove they were written down by picking 2 of them, sign in with the words or an `nsec`, or sign out. Each step
/// writes to the store at once, and a fault shows as `failure`.
@MainActor
@Observable
public final class AccountFlow {
    public enum Step: Equatable, Sendable {
        case choose, about, words, check, restore, account, signOut, done
    }

    /// One word of the check: its place among the 12, the 4 words to pick from, and the pick.
    public struct Check: Equatable, Sendable {
        public let position: Int
        public let choices: [String]
        public var picked: String?
    }

    public static let wordCount = 12

    private let store: AccountStore
    public private(set) var step: Step
    public private(set) var words: [String] = []
    public private(set) var checks: [Check] = []
    public private(set) var mistake: String?
    public private(set) var failure: String?
    /// One word of the phrase being typed, and whether it is a word of the list, or starts one while it is being typed.
    public struct TypedWord: Equatable, Sendable {
        public let text: String
        public let isKnown: Bool
    }

    /// What the person typed or pasted to sign in: the 12 words, or an `nsec`.
    public var phrase = ""
    /// Whether the sign-in takes an `nsec` in place of the words.
    public var usesNsec = false

    /// Whether the Mac held a key when the flow began, so that its words show only after Touch ID.
    public let hadKey: Bool

    public init(store: AccountStore, step: Step) {
        self.store = store
        self.step = step
        hadKey = (try? store.key()) != nil
        if step == .words { words = (try? store.key())?.words ?? [] }
    }

    /// The flow on the step that the account's state calls for: set up with no key, the words with a key that is not
    /// backed up, and the account with one that is.
    public convenience init(store: AccountStore) {
        let key = try? store.key()
        self.init(store: store, step: key == nil ? .choose : (try? store.isBackedUp()) == true ? .account : .about)
    }

    nonisolated deinit {}

    /// The `npub` of the kept key.
    public var npub: String? {
        (try? store.key())?.npub
    }

    /// Whether the person has the words of the kept key.
    public var isBackedUp: Bool {
        (try? store.isBackedUp()) == true
    }

    /// What a sign-out takes away, and what brings the account back.
    public var signOutWords: String {
        let place = (try? store.isSyncing()) == true ? "this Mac and from your other Macs that use iCloud Keychain" : "this Mac"
        guard isBackedUp else {
            return "Openspot removes your account from \(place). You haven't saved its 12 words, so you can't sign in to it again."
        }
        return "Openspot removes your account from \(place). You can sign in again with your 12 words."
    }

    /// Moves to another step, such as from the choice to the sign-in.
    public func start(_ step: Step) {
        failure = nil
        self.step = step
    }

    /// Says what the words are, before a key is made.
    public func create() {
        start(.about)
    }

    /// Shows the words of the kept key, or of a new key that it makes and keeps.
    public func showWords() {
        attempt {
            let key = try store.keyMadeOnce()
            words = key.words ?? []
            step = .words
        }
    }

    /// Asks for 2 of the words, each among 4.
    public func wroteThemDown() {
        let positions = Array((1...words.count).shuffled().prefix(2)).sorted()
        checks = positions.map { position in
            let right = words[position - 1]
            let others = AccountWords.all.filter { $0 != right }.shuffled().prefix(3)
            return Check(position: position, choices: ([right] + others).shuffled())
        }
        mistake = nil
        step = .check
    }

    /// Takes a pick of a check, and marks the words backed up once each pick is right.
    public func pick(_ word: String, at index: Int) {
        guard checks.indices.contains(index) else { return }
        checks[index].picked = word
        let position = checks[index].position
        guard word == words[position - 1] else {
            mistake = "That isn't word \(position). Look at your words again."
            return
        }
        mistake = nil
        guard checks.allSatisfy({ $0.picked == words[$0.position - 1] }) else { return }
        attempt {
            try store.markBackedUp()
            step = .done
        }
    }

    public func showWordsAgain() {
        mistake = nil
        step = .words
    }

    /// Each word of the phrase. The last one is still being typed until a space follows it.
    public var typed: [TypedWord] {
        guard !isNsec else { return [] }
        let words = phrase.split(whereSeparator: \.isWhitespace).map { $0.lowercased() }
        let isTyping = phrase.last.map { !$0.isWhitespace } ?? false
        return words.enumerated().map { index, word in
            let isLast = index == words.count - 1 && isTyping
            return TypedWord(text: word, isKnown: isLast ? !Self.suggestions(for: word).isEmpty : AccountWords.all.contains(word))
        }
    }

    /// How many words the phrase holds, such as `8 of 12`.
    public var counter: String {
        "\(typed.count) of \(Self.wordCount)"
    }

    /// The word of the list that the word being typed starts, which Tab puts in its place.
    public var completion: String? {
        guard !isNsec, let last = phrase.last, !last.isWhitespace, let word = typed.last?.text else { return nil }
        return Self.suggestions(for: word).first.flatMap { $0 == word ? nil : $0 }
    }

    /// Puts the completion in place of the word being typed, and a space after it.
    public func complete() {
        guard let completion, let word = typed.last?.text else { return }
        phrase = String(phrase.dropLast(word.count)) + completion + " "
    }

    /// The `npub` of the account that the phrase signs in to, once it is one.
    public var account: String? {
        canSignIn ? (try? enteredKey())?.npub : nil
    }

    /// Why the phrase is no account, once it is long enough to be one, or nil.
    public var problem: String? {
        if isNsec {
            guard trimmed.count >= Self.nsecLength else { return nil }
            return (try? enteredKey()) == nil ? "This is not an nsec." : nil
        }
        let words = typed
        guard words.count >= Self.wordCount else { return nil }
        guard words.count == Self.wordCount else { return "An account has \(Self.wordCount) words, and this has \(words.count)." }
        if let unknown = words.first(where: { !AccountWords.all.contains($0.text) }) { return "\(unknown.text) isn't one of the account words." }
        return (try? enteredKey()) == nil ? "These words don't match an account. Check each word and their order." : nil
    }

    public var canSignIn: Bool {
        (isNsec ? trimmed.count >= Self.nsecLength : typed.count == Self.wordCount) && problem == nil
    }

    /// What a sign-in replaces, when this Mac holds another key.
    public var replacing: String? {
        guard let kept = try? store.key() else { return nil }
        if let key = try? enteredKey(), key.publicKey == kept.publicKey { return nil }
        return "This replaces the account on this Mac. Spots you published with it will publish as new spots."
    }

    /// Keeps the key of the phrase, marked as backed up, since the person has its words.
    public func signIn() {
        attempt {
            try store.keep(try enteredKey(), isBackedUp: true)
            step = .done
        }
    }

    public func signOut() {
        attempt {
            try store.remove()
            step = .done
        }
    }

    /// The words of the list that start with these letters.
    public static func suggestions(for letters: String) -> [String] {
        let letters = letters.lowercased()
        guard !letters.isEmpty else { return [] }
        return AccountWords.all.filter { $0.hasPrefix(letters) }
    }

    private static let nsecLength = 63

    private var trimmed: String {
        phrase.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether the phrase is an `nsec`, by the choice of the person or by its start.
    private var isNsec: Bool {
        usesNsec || trimmed.lowercased().hasPrefix("nsec1")
    }

    private func enteredKey() throws -> AccountKey {
        isNsec ? try AccountKey(nsec: trimmed) : try AccountKey(words: typed.map(\.text))
    }

    private func attempt(_ work: () throws -> Void) {
        do {
            failure = nil
            try work()
        } catch {
            failure = (error as? SpotError)?.reason ?? error.localizedDescription
        }
    }
}
