import Foundation
import Observation

/// The steps of the account window: choose between a new account and an existing one, see the 12 words, prove they were
/// written down by picking 2 of them, sign in with the words or an `nsec`, or sign out. Each step writes to the store
/// at once, and a fault shows as `failure`.
@MainActor
@Observable
public final class AccountFlow {
    public enum Step: Equatable, Sendable {
        case choose, words, check, restore, signOut, done
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
    /// The words typed or pasted to sign in, one per box, or an `nsec` in the first.
    public var boxes = Array(repeating: "", count: AccountFlow.wordCount)

    public init(store: AccountStore, step: Step) {
        self.store = store
        self.step = step
        if step == .words { words = (try? store.key())?.words ?? [] }
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

    /// Makes and keeps a new key, and shows its words.
    public func create() {
        attempt {
            let key = try AccountKey.make()
            try store.keep(key)
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

    /// Puts a pasted phrase into the boxes, a word each, or an `nsec` into the first.
    public func paste(_ text: String) {
        let parts = text.split(whereSeparator: \.isWhitespace).map { $0.lowercased() }
        boxes = (parts + Array(repeating: "", count: Self.wordCount)).prefix(Self.wordCount).map { $0 }
    }

    /// The boxes whose word is not in the list.
    public var unknownBoxes: [Int] {
        guard !isNsec else { return [] }
        return boxes.indices.filter { !boxes[$0].isEmpty && !AccountWords.all.contains(boxes[$0].lowercased()) }
    }

    /// Why the boxes are not a key, once each holds a word, or nil.
    public var problem: String? {
        guard isNsec || boxes.allSatisfy({ !$0.isEmpty }) else { return nil }
        do {
            _ = try enteredKey()
            return nil
        } catch {
            return (error as? SpotError)?.reason ?? error.localizedDescription
        }
    }

    public var canSignIn: Bool {
        (isNsec || boxes.allSatisfy { !$0.isEmpty }) && problem == nil
    }

    /// What a sign-in replaces, when this Mac holds another key.
    public var replacing: String? {
        guard let kept = try? store.key() else { return nil }
        if let key = try? enteredKey(), key.publicKey == kept.publicKey { return nil }
        return "This replaces the account on this Mac. Spots you published with it will publish as new spots."
    }

    /// Keeps the key of the boxes, marked as backed up, since the person has its words.
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

    private var isNsec: Bool {
        boxes[0].hasPrefix("nsec") && boxes.dropFirst().allSatisfy(\.isEmpty)
    }

    private func enteredKey() throws -> AccountKey {
        isNsec ? try AccountKey(nsec: boxes[0]) : try AccountKey(words: boxes.map { $0.lowercased() })
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
