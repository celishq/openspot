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

    private enum Page: String, CaseIterable {
        case handle, restore, how, about, check, leave
    }

    private enum Move {
        case push(Page), pop, popAll

        var effect: SpotEffect {
            switch self {
            case .push(let page): .route(.push(spot: nil, route: page.rawValue, title: nil, replace: false))
            case .pop: .route(.pop(all: false))
            case .popAll: .route(.pop(all: true))
            }
        }
    }

    public static let id = "openspot/account"
    public static let card = "openspot:account-card"

    private let account: Account
    private let links: Links
    private var shows = false
    private var wordCheck: WordCheck?

    public init(store: AccountStore, links: Links) {
        account = Account(store: store, allows: links.allows)
        self.links = links
    }

    public nonisolated var spot: Spot {
        Spot(
            id: Self.id, name: "Account", url: URL(fileURLWithPath: NSTemporaryDirectory()), kind: .list, icon: .symbol("person.crop.circle"),
            subtitle: "Signs what you publish", on: .sheet, host: .account(self), isGlobal: true, dataName: "account",
            isOnGrid: false, views: ["card": Self.card], pages: Page.allCases.map(\.rawValue), uses: [.app, .account, .clipboard]
        ).builtIn()
    }

    func answer(_ arguments: [String], input: String?) async throws -> HostAnswer {
        let fields = TextBlock.blocks(in: input ?? "").first
        let reason = fields?.value("event")
        let page = fields?.value("route").flatMap(Page.init(rawValue:))
        var toast: String?
        var phrase = ""
        var handle: String?
        var move: Move?
        if reason != nil { shows = false }
        let action = arguments.first ?? ""
        switch action {
        case "show":
            break
        case "sign_in":
            phrase = fields?.value("input.phrase") ?? ""
            let typed = AccountPhrase(phrase)
            if typed.canSignIn {
                try await account.signIn(typed)
                phrase = ""
                toast = "Signed in"
                _ = await links.publish()
                move = .popAll
            }
        case "phrase":
            phrase = arguments.count > 1 ? arguments[1] : ""
        case "new":
            move = .push(.handle)
        case "handle":
            handle = AccountHandle.suggestion(from: arguments.dropFirst().first ?? "")
        case "create":
            let typed = AccountHandle.suggestion(from: fields?.value("input.handle") ?? "")
            guard AccountHandle(typed) != nil else {
                handle = typed
                break
            }
            try account.make(handle: typed)
            _ = await links.publish()
            move = .popAll
        case "own":
            move = .push(.restore)
        case "card":
            if arguments.dropFirst().first == "copy", let npub = try account.status().npub, await links.copy(npub) { toast = "Copied your key" }
        case "how":
            move = .push(.how)
        case "about":
            move = .push(.about)
        case "reveal":
            shows = true
        case "wrote":
            shows = false
            if try account.status().sync == true {
                move = .pop
            } else {
                wordCheck = WordCheck(places: Self.twoPlaces())
                move = .push(.check)
            }
        case "leave":
            move = .push(.leave)
        case "again", "cancel", "done", "later":
            shows = false
            move = .pop
        case "sign_out":
            try await account.signOut()
            toast = "Signed out"
            move = .popAll
        case "sync":
            try await account.sync(arguments.dropFirst().first == "true")
        case let id where id.hasPrefix("pick-"):
            (toast, move) = try await picked(id)
        default:
            throw SpotError.failed(1, "Account cannot do that.")
        }
        let frame = try await sheet(on: page, phrase: phrase, handle: handle)
        return HostAnswer(frame: frame, effects: [move?.effect, toast.map(SpotEffect.toast)].compactMap { $0 })
    }

    private func step(on page: Page?, _ facts: AccountStatus) -> Step {
        switch (page, facts.signedIn) {
        case (.how?, _): return .how
        case (.restore?, _): return .restore
        case (.handle?, false): return .handle
        case (.about?, true): return shows ? .words : .about
        case (.leave?, true): return .leave
        case (.check?, true) where facts.backedUp != true: return .check(wordCheck ?? WordCheck(places: Self.twoPlaces()))
        default: return facts.signedIn ? .account : .choose
        }
    }

    private func picked(_ id: String) async throws -> (String?, Move?) {
        let rest = id.dropFirst("pick-".count)
        guard let dash = rest.firstIndex(of: "-"), let place = Int(rest[..<dash]) else { return (nil, nil) }
        let word = String(rest[rest.index(after: dash)...])
        guard var check = wordCheck else { return (nil, nil) }
        guard let first = check.pick, first.place != place else {
            check.pick = Pick(place: place, word: word)
            wordCheck = check
            return (nil, nil)
        }
        do {
            try await account.confirm([(first.place, first.word), (place, word)])
        } catch let error as SpotError {
            check.pick = nil
            check.mistake = error.reason
            wordCheck = check
            return (nil, nil)
        }
        wordCheck = nil
        return ("Your words are backed up", .popAll)
    }

    private static func twoPlaces() -> [Int] {
        Array((1...AccountPhrase.wordCount).shuffled().prefix(2)).sorted()
    }

    private func sheet(on page: Page?, phrase: String, handle: String?) async throws -> String {
        let facts = try account.status()
        var frame = AccountFrame()
        switch step(on: page, facts) {
        case .restore: restore(&frame, facts, phrase: phrase)
        case .check(let check): self.check(&frame, check)
        case .choose: choose(&frame)
        case .handle: self.handle(&frame, typed: handle)
        case .how: how(&frame)
        case .about: about(&frame, facts)
        case .words: await words(&frame, facts)
        case .account: account(&frame, facts)
        case .leave: leave(&frame, facts)
        }
        return frame.text
    }

    private func choose(_ frame: inout AccountFrame) {
        frame.rows("head", "new", "own how")
        frame.line("head", "You need a key to publish", icon: "signature", detail: "Openspot signs your spots with it, so people know an update is from you.")
        frame.button("new", "Create a new key", .main)
        frame.button("own", "Use my own key")
        frame.button("how", "How it works")
    }

    private func handle(_ frame: inout AccountFrame, typed: String?) {
        let value = typed ?? AccountHandle.suggestion(from: links.userName())
        let problem = typed != nil && AccountHandle(value) == nil ? AccountHandle.rule : nil
        frame.rows("head", "label", "handle")
        if problem != nil { frame.rows("status") }
        frame.rows("create")
        frame.line("head", "Pick your handle", icon: "at", detail: "It names you on the spots you publish, and in their links.")
        frame.block(["text": "label", "class": "font-section", "title": "Handle"], order: ["text", "class", "title"])
        frame.block(["field": "handle", "grow": "false", "placeholder": "yourname", "value": value], order: ["field", "grow", "placeholder", "value"])
        if let problem { frame.line("status", problem, icon: "exclamationmark.triangle", tone: "bad") }
        frame.button("create", "Create key", .main)
        frame.howAction()
    }

    private func how(_ frame: inout AccountFrame) {
        frame.rows("head", "people", "icloud", "words", "private", "reset", "done")
        frame.line("head", "How your key works", icon: "key", detail: "Openspot signs each spot you publish with your key. There is no email, password or server.")
        frame.line("people", "Shows an update is yours", icon: "checkmark.seal")
        frame.line("icloud", "Kept in iCloud Keychain", icon: "icloud")
        frame.line("words", "12 words bring it back", icon: "list.number")
        frame.line("private", "Anyone with the words is you", icon: "eye.slash")
        frame.line("reset", "Nobody can reset them", icon: "exclamationmark.triangle", tone: "warn")
        frame.button("done", "Done", .main)
    }

    private func about(_ frame: inout AccountFrame, _ facts: AccountStatus) {
        frame.rows("head", "private", "reset")
        if facts.sync == true { frame.rows("icloud") }
        frame.rows("reveal")
        frame.line("head", "Your 12 words are your key", icon: "key", detail: "They bring your key back on any Mac.")
        frame.line("private", "Anyone with them is you", icon: "eye.slash")
        frame.line("reset", "Nobody can reset them", icon: "exclamationmark.triangle", tone: "warn")
        if facts.sync == true { frame.line("icloud", "iCloud Keychain keeps a copy", icon: "icloud") }
        frame.button("reveal", "Show my words", .main)
        frame.howAction()
    }

    private func words(_ frame: inout AccountFrame, _ facts: AccountStatus) async {
        frame.rows("head")
        frame.wordRows()
        frame.rows("wrote", "later")
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

    private func account(_ frame: inout AccountFrame, _ facts: AccountStatus) {
        frame.rows("card", "backup")
        frame.style("card", "h-44")
        if facts.sync != nil { frame.rows("sync") }
        frame.rows("about", "-", "how leave")
        let npub = facts.npub ?? ""
        var card = ["card": "card", "grow": "false", "npub": npub, "short": facts.shortNpub ?? ""]
        var order = ["card", "grow", "npub", "short"]
        if let handle = facts.handle { card["handle"] = handle; order.append("handle") }
        if let since = facts.since.flatMap(Self.month) { card["since"] = since; order.append("since") }
        frame.block(card, order: order)
        frame.block(["text": "backup", "class": "font-section", "title": "Backup"], order: ["text", "class", "title"])
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

    private func leave(_ frame: inout AccountFrame, _ facts: AccountStatus) {
        frame.rows("head")
        if facts.backedUp != true { frame.rows("again") }
        frame.rows("sign_out", "cancel")
        let place = facts.sync == true ? "all your Macs" : "this Mac"
        let again = facts.backedUp == true ? " Your 12 words sign you in again." : ""
        frame.line("head", "Sign out of your account?", icon: "rectangle.portrait.and.arrow.right", detail: "It leaves \(place).\(again)")
        if facts.backedUp != true { frame.line("again", "You haven't saved its words", icon: "exclamationmark.triangle", tone: "bad") }
        frame.button("sign_out", "Sign out", .main)
        frame.button("cancel", "Cancel")
        frame.howAction()
    }

    private func restore(_ frame: inout AccountFrame, _ facts: AccountStatus, phrase: String) {
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
        frame.rows("phrase")
        frame.style("phrase", "h-32")
        if status != nil { frame.rows("status") }
        frame.rows("sign_in")
        frame.block(["field": "phrase", "type": "multiline", "grow": "false", "placeholder": "Your 12 words, or an nsec", "value": phrase], order: ["field", "type", "grow", "placeholder", "value"])
        if let status { frame.line("status", status.title, icon: status.icon, tone: status.tone, detail: status.detail) }
        frame.button("sign_in", "Sign in", .main)
    }

    private func check(_ frame: inout AccountFrame, _ check: WordCheck) {
        let (first, second) = (check.places[0], check.places[1])
        let choices = (try? account.choices(at: [first, second])) ?? [[], []]
        let ids = zip([first, second], choices).map { place, words in words.map { "pick-\(place)-\($0)" } }
        frame.rows("head", "first")
        if ids[0].count == 4 { frame.rows("\(ids[0][0]) \(ids[0][1])", "\(ids[0][2]) \(ids[0][3])") }
        frame.rows("second")
        if ids[1].count == 4 { frame.rows("\(ids[1][0]) \(ids[1][1])", "\(ids[1][2]) \(ids[1][3])") }
        frame.rows("again")
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
