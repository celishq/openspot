import Foundation

public actor AccountSheet {
    public struct Links: Sendable {
        let allows: @Sendable (String) async -> Bool
        let copy: @Sendable (String) async -> Bool
        let publish: @Sendable () async -> Bool
        let userName: @Sendable () -> String

        public init(
            allows: @escaping @Sendable (String) async -> Bool,
            copy: @escaping @Sendable (String) async -> Bool,
            publish: @escaping @Sendable () async -> Bool,
            userName: @escaping @Sendable () -> String
        ) {
            self.allows = allows
            self.copy = copy
            self.publish = publish
            self.userName = userName
        }
    }

    private struct Pick: Equatable {
        let place: Int
        let word: String
    }

    private struct WordCheck: Equatable {
        let places: [Int]
        var pick: Pick?
        var mistake: String?
    }

    private enum Step: Equatable {
        case choose, handle, how, about, words, check(WordCheck), account, leave, restore
    }

    public static let id = "openspot/account"
    public static let card = "openspot:account-card"

    private let account: Account
    private let links: Links
    private var saved: Step?

    public init(store: AccountStore, links: Links) {
        account = Account(store: store, allows: links.allows)
        self.links = links
    }

    public nonisolated var spot: Spot {
        Spot(
            id: Self.id, name: "Account", url: URL(fileURLWithPath: NSTemporaryDirectory()), kind: .list, icon: .symbol("person.crop.circle"),
            subtitle: "Signs what you publish", read: .sheet, host: .account(self), offeredPlaces: [.search], dataName: "account",
            isOnGrid: false, view: Self.card, uses: [.app, .account, .clipboard]
        ).builtIn()
    }

    func answer(_ arguments: [String], input: String?, variables: [String: String]) async throws -> String {
        let fields = TextBlock.blocks(in: input ?? "").first
        let reason = variables["OPENSPOT_REASON"]
        var toast: String?
        var phrase = ""
        var handle: String?
        var pops = false
        let action = arguments.first ?? ""
        switch action {
        case "read":
            break
        case "sign_in":
            if try step(reason: reason, try account.status()) == .restore {
                phrase = fields?.value("phrase") ?? ""
                let typed = AccountPhrase(phrase)
                if typed.canSignIn {
                    try await account.signIn(typed)
                    saved = .account
                    phrase = ""
                    toast = "Signed in"
                    pops = await publishWaiting()
                }
            } else {
                saved = .restore
            }
        case "phrase":
            phrase = arguments.count > 1 ? arguments[1] : ""
        case "new":
            saved = .handle
        case "handle":
            handle = AccountHandle.suggestion(from: arguments.dropFirst().first ?? "")
        case "create":
            let typed = AccountHandle.suggestion(from: fields?.value("handle") ?? "")
            guard AccountHandle(typed) != nil else {
                handle = typed
                break
            }
            try account.make(handle: typed)
            saved = nil
            pops = await publishWaiting()
        case "own":
            saved = .restore
        case "card":
            if arguments.dropFirst().first == "copy", let npub = try account.status().npub, await links.copy(npub) { toast = "Copied your key" }
        case "how":
            saved = .how
        case "about":
            saved = .about
        case "show", "again":
            saved = .words
        case "wrote":
            if try account.status().sync == true {
                saved = nil
            } else {
                saved = .check(WordCheck(places: Self.twoPlaces()))
            }
        case "leave":
            saved = .leave
        case "back", "cancel", "done", "later":
            saved = nil
        case "sign_out":
            try await account.signOut()
            saved = nil
            toast = "Signed out"
        case "sync":
            try await account.sync(arguments.dropFirst().first == "true")
        case let id where id.hasPrefix("pick-"):
            toast = try await picked(id)
        default:
            throw SpotError.failed(1, "Account cannot do that.")
        }
        return try await sheet(reason: action == "read" ? reason : nil, toast: toast, phrase: phrase, handle: handle, pops: pops)
    }

    private func step(reason: String?, _ facts: AccountStatus) throws -> Step {
        if reason != nil, saved == .words { saved = nil }
        switch (saved, facts.signedIn) {
        case let (step?, _) where [.how, .restore].contains(step): return step
        case (.handle?, false): return .handle
        case let (step?, true) where [.about, .words, .account, .leave].contains(step): return step
        case let (.check(check)?, true) where facts.backedUp != true: return .check(check)
        default: return facts.signedIn ? .account : .choose
        }
    }

    private func publishWaiting() async -> Bool {
        guard await links.publish() else { return false }
        saved = nil
        return true
    }

    private func picked(_ id: String) async throws -> String? {
        let rest = id.dropFirst("pick-".count)
        guard let dash = rest.firstIndex(of: "-"), let place = Int(rest[..<dash]) else { return nil }
        let word = String(rest[rest.index(after: dash)...])
        guard case .check(var check)? = saved else { return nil }
        guard let first = check.pick, first.place != place else {
            check.pick = Pick(place: place, word: word)
            saved = .check(check)
            return nil
        }
        do {
            try await account.confirm([(first.place, first.word), (place, word)])
        } catch let error as SpotError {
            check.pick = nil
            check.mistake = error.reason
            saved = .check(check)
            return nil
        }
        saved = .account
        return "Your words are backed up"
    }

    private static func twoPlaces() -> [Int] {
        Array((1...AccountPhrase.wordCount).shuffled().prefix(2)).sorted()
    }

    private func sheet(reason: String?, toast: String?, phrase: String, handle: String?, pops: Bool) async throws -> String {
        let facts = try account.status()
        var frame = AccountFrame()
        if pops { frame.head("pop", "true") }
        switch try step(reason: reason, facts) {
        case .restore: restore(&frame, facts, phrase: phrase, toast: toast)
        case .check(let check): self.check(&frame, check, toast: toast)
        case .choose: choose(&frame, toast: toast)
        case .handle: self.handle(&frame, typed: handle, toast: toast)
        case .how: how(&frame, toast: toast)
        case .about: about(&frame, facts, toast: toast)
        case .words: await words(&frame, facts, toast: toast)
        case .account: account(&frame, facts, toast: toast)
        case .leave: leave(&frame, facts, toast: toast)
        }
        return frame.text
    }

    private func choose(_ frame: inout AccountFrame, toast: String?) {
        frame.grid("head head", "head head", "new new", "own how")
        frame.toast(toast)
        frame.line("head", "You need a key to publish", icon: "signature", detail: "Openspot signs your spots with it, so people know an update is from you.")
        frame.button("new", "Create a new key", .main)
        frame.button("own", "Use my own key")
        frame.howAction()
    }

    private func handle(_ frame: inout AccountFrame, typed: String?, toast: String?) {
        let value = typed ?? AccountHandle.suggestion(from: links.userName())
        let problem = typed != nil && AccountHandle(value) == nil ? AccountHandle.rule : nil
        frame.grid("head head", "head head", "label label", "handle handle")
        if problem != nil { frame.grid("status status") }
        frame.grid("back create")
        frame.toast(toast)
        frame.line("head", "Pick your handle", icon: "at", detail: "It names you on the spots you publish, and in their links.")
        frame.block(["section": "label", "title": "Handle"], order: ["section", "title"])
        frame.block(["field": "handle", "grow": "false", "placeholder": "yourname", "value": value], order: ["field", "grow", "placeholder", "value"])
        if let problem { frame.line("status", problem, icon: "exclamationmark.triangle", tone: "bad") }
        frame.button("back", "Back")
        frame.button("create", "Create key", .main)
        frame.howAction()
    }

    private func how(_ frame: inout AccountFrame, toast: String?) {
        frame.grid("head", "head", "people", "icloud", "words", "private", "reset", "done")
        frame.toast(toast)
        frame.line("head", "How your key works", icon: "key", detail: "Openspot signs each spot you publish with your key. There is no email, password or server.")
        frame.line("people", "Shows an update is yours", icon: "checkmark.seal")
        frame.line("icloud", "Kept in iCloud Keychain", icon: "icloud")
        frame.line("words", "12 words bring it back", icon: "list.number")
        frame.line("private", "Anyone with the words is you", icon: "eye.slash")
        frame.line("reset", "Nobody can reset them", icon: "exclamationmark.triangle", tone: "warn")
        frame.button("done", "Done", .main)
    }

    private func about(_ frame: inout AccountFrame, _ facts: AccountStatus, toast: String?) {
        frame.grid("head", "head", "private", "reset")
        if facts.sync == true { frame.grid("icloud") }
        frame.grid("show")
        frame.toast(toast)
        frame.line("head", "Your 12 words are your key", icon: "key", detail: "They bring your key back on any Mac.")
        frame.line("private", "Anyone with them is you", icon: "eye.slash")
        frame.line("reset", "Nobody can reset them", icon: "exclamationmark.triangle", tone: "warn")
        if facts.sync == true { frame.line("icloud", "iCloud Keychain keeps a copy", icon: "icloud") }
        frame.button("show", "Show my words", .main)
        frame.howAction()
    }

    private func words(_ frame: inout AccountFrame, _ facts: AccountStatus, toast: String?) async {
        frame.grid("head head")
        frame.wordGrid()
        frame.grid("wrote wrote", "later later")
        frame.toast(toast)
        do {
            let words = try await account.words()
            frame.line("head", "Write them down", icon: "pencil", detail: "In this order")
            for (index, word) in words.enumerated() { frame.word(index + 1, word) }
        } catch {
            frame.line("head", (error as? SpotError)?.reason ?? error.localizedDescription, icon: "exclamationmark.triangle", tone: "bad")
        }
        frame.button("wrote", "I wrote them down", .main)
        frame.button("later", facts.backedUp == true ? "Done" : "Later", .close)
        frame.howAction()
    }

    private func account(_ frame: inout AccountFrame, _ facts: AccountStatus, toast: String?) {
        frame.grid("card card", "card card", "card card", "card card", "backup backup")
        if facts.sync != nil { frame.grid("sync sync") }
        frame.grid("about about", "- -", "how leave")
        frame.toast(toast)
        let npub = facts.npub ?? ""
        var card = ["view": "card", "grow": "false", "npub": npub, "short": facts.shortNpub ?? ""]
        var order = ["view", "grow", "npub", "short"]
        if let handle = facts.handle { card["handle"] = handle; order.append("handle") }
        if let since = facts.since.flatMap(Self.month) { card["since"] = since; order.append("since") }
        frame.block(card, order: order)
        frame.block(["section": "backup", "title": "Backup"], order: ["section", "title"])
        if let sync = facts.sync {
            frame.block(["switch": "sync", "title": "Keep in iCloud Keychain", "icon": "icloud", "look": "tile", "value": String(sync)], order: ["switch", "title", "icon", "look", "value"])
        }
        let saved: (detail: String, tone: String?) = facts.backedUp == true ? ("Saved", "good") : facts.sync == true ? ("In iCloud Keychain", nil) : ("Not saved yet", "warn")
        var words = ["button": "about", "title": "Recovery words", "detail": saved.detail, "icon": "key", "look": "tile"]
        var keys = ["button", "title", "detail", "icon", "look"]
        if let tone = saved.tone { words["tone"] = tone; keys.append("tone") }
        frame.block(words, order: keys)
        frame.button("how", "How it works")
        frame.button("leave", "Sign out…")
    }

    private func leave(_ frame: inout AccountFrame, _ facts: AccountStatus, toast: String?) {
        frame.grid("head", "head")
        if facts.backedUp != true { frame.grid("again") }
        frame.grid("sign_out", "cancel")
        frame.toast(toast)
        let place = facts.sync == true ? "all your Macs" : "this Mac"
        let again = facts.backedUp == true ? " Your 12 words sign you in again." : ""
        frame.line("head", "Sign out of your account?", icon: "rectangle.portrait.and.arrow.right", detail: "It leaves \(place).\(again)")
        if facts.backedUp != true { frame.line("again", "You haven't saved its words", icon: "exclamationmark.triangle", tone: "bad") }
        frame.button("sign_out", "Sign out", .main)
        frame.button("cancel", "Cancel")
        frame.howAction()
    }

    private func restore(_ frame: inout AccountFrame, _ facts: AccountStatus, phrase: String, toast: String?) {
        let typed = phrase.isEmpty ? nil : AccountPhrase(phrase)
        let finished = (typed?.typed ?? []).dropLast(phrase.last?.isWhitespace == true ? 0 : 1)
        var status: (title: String, icon: String?, tone: String?, detail: String?)?
        if let problem = typed?.problem {
            status = (problem, "exclamationmark.triangle", "bad", nil)
        } else if let account = typed?.account {
            status = facts.signedIn
                ? ("Replaces the account on this Mac", "exclamationmark.triangle", "warn", AccountKey.short(account))
                : ("Signs in as", "checkmark.circle", "good", AccountKey.short(account))
        } else if let unknown = finished.first(where: { !$0.isKnown }) {
            status = ("\(unknown.text) isn't an account word", "exclamationmark.triangle", "bad", nil)
        } else if let completion = typed?.completion {
            status = ("Did you mean \(completion)?", "questionmark.circle", nil, nil)
        } else if let typed {
            status = (typed.counter, nil, nil, nil)
        }
        frame.grid("phrase phrase", "phrase phrase", "phrase phrase")
        if status != nil { frame.grid("status status") }
        frame.grid("back sign_in")
        frame.toast(toast)
        frame.block(["field": "phrase", "type": "multiline", "grow": "false", "placeholder": "Your 12 words, or an nsec", "value": phrase], order: ["field", "type", "grow", "placeholder", "value"])
        if let status { frame.line("status", status.title, icon: status.icon, tone: status.tone, detail: status.detail) }
        frame.button("sign_in", "Sign in", .main)
        frame.button("back", "Back")
    }

    private func check(_ frame: inout AccountFrame, _ check: WordCheck, toast: String?) {
        let (first, second) = (check.places[0], check.places[1])
        let choices = (try? account.choices(at: [first, second])) ?? [[], []]
        let ids = zip([first, second], choices).map { place, words in words.map { "pick-\(place)-\($0)" } }
        frame.grid("head head", "first first")
        if ids[0].count == 4 { frame.grid("\(ids[0][0]) \(ids[0][1])", "\(ids[0][2]) \(ids[0][3])") }
        frame.grid("second second")
        if ids[1].count == 4 { frame.grid("\(ids[1][0]) \(ids[1][1])", "\(ids[1][2]) \(ids[1][3])") }
        frame.grid("again again")
        frame.toast(toast)
        if let mistake = check.mistake {
            frame.line("head", mistake, icon: "exclamationmark.triangle", tone: "bad")
        } else {
            frame.line("head", "Pick each word you wrote", icon: "checkmark.circle")
        }
        frame.block(["text": "first", "title": "Word \(first)", "icon": "\(first).circle"], order: ["text", "title", "icon"])
        frame.block(["text": "second", "title": "Word \(second)", "icon": "\(second).circle"], order: ["text", "title", "icon"])
        for (place, words) in zip([first, second], choices) {
            for word in words {
                let isPicked = check.pick == Pick(place: place, word: word)
                frame.button("pick-\(place)-\(word)", word, isPicked ? .picked : .plain)
            }
        }
        frame.button("again", "Show the words again")
    }

    private static func month(_ day: String) -> String? {
        let reader = DateFormatter()
        reader.locale = Locale(identifier: "en_US_POSIX")
        reader.dateFormat = "yyyy-MM-dd"
        guard let date = reader.date(from: day) else { return nil }
        let writer = DateFormatter()
        writer.locale = Locale(identifier: "en_US_POSIX")
        writer.dateFormat = "MMM yyyy"
        return writer.string(from: date)
    }
}

extension AccountSheet: Equatable {
    public static func == (left: AccountSheet, right: AccountSheet) -> Bool {
        left === right
    }
}
