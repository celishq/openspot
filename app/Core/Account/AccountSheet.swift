import Foundation

public actor AccountSheet {
    public struct Links: Sendable {
        let allows: @Sendable (String) async -> Bool
        let copy: @Sendable (String) async -> Bool
        let publish: @Sendable (String) async -> Void
        let userName: @Sendable () -> String

        public init(
            allows: @escaping @Sendable (String) async -> Bool,
            copy: @escaping @Sendable (String) async -> Bool,
            publish: @escaping @Sendable (String) async -> Void,
            userName: @escaping @Sendable () -> String
        ) {
            self.allows = allows
            self.copy = copy
            self.publish = publish
            self.userName = userName
        }
    }

    private enum Step {
        case choose, name, how, about, words, check, account, leave, restore
    }

    private struct Facts {
        let npub: String?
        let name: String?
        let since: String?
        let isBackedUp: Bool
        let sync: Bool?

        var isSignedIn: Bool { npub != nil }
    }

    public static let id = "openspot/account"
    public static let card = "openspot:account-card"
    public static let publishPrefix = "publish:"
    private static let header = [
        "title=Account", "icon=person.crop.circle", "detail=Signs what you publish", "on=sheet.open", "uses=app,account,clipboard",
        "offers=search", "pages=\(publishPrefix)*",
    ]

    private let store: AccountStore
    private let links: Links
    private var saved: Step?
    private var mistake: String?
    private var pick: (place: Int, word: String)?
    private var places = (1, 12)

    public init(store: AccountStore, links: Links) {
        self.store = store
        self.links = links
    }

    public nonisolated var spot: Spot {
        let header = TextBlock(fields: Self.header.map { line in
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            return TextBlock.Field(key: parts[0], value: parts[1])
        })
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("account.sh")
        let made = (try? SpotFile(script: url, header: header, id: Self.id).spots.first) ?? Spot(id: Self.id, name: "Account", url: url)
        return made.builtIn().hosted(by: .account(self), view: Self.card)
    }

    func answer(_ arguments: [String], input: String?, variables: [String: String]) async throws -> String {
        let page = variables["OPENSPOT_PAGE"] ?? ""
        let publishing = page.hasPrefix(Self.publishPrefix) ? String(page.dropFirst(Self.publishPrefix.count)) : nil
        let fields = TextBlock.blocks(in: input ?? "").first
        let reason = variables["OPENSPOT_REASON"]
        var toast: String?
        var phrase = ""
        var pops = false
        let action = arguments.first ?? ""
        switch action {
        case "read":
            break
        case "sign_in":
            if try step(reason: reason, try facts()) == .restore {
                phrase = fields?.value("phrase") ?? ""
                let typed = AccountPhrase(phrase)
                if typed.canSignIn, let key = try? typed.key() {
                    try store.keep(key, isBackedUp: true)
                    go(.account)
                    phrase = ""
                    toast = "Signed in"
                    if let publishing { pops = await publish(publishing) }
                }
            } else {
                go(.restore)
            }
        case "phrase":
            phrase = arguments.count > 1 ? arguments[1] : ""
        case "new":
            go(.name)
        case "create":
            let name = (fields?.value("name") ?? "").trimmingCharacters(in: .whitespaces)
            _ = try store.keyMadeOnce(name: name.isEmpty ? nil : name)
            saved = nil
            if let publishing { pops = await publish(publishing) }
        case "own":
            go(.restore)
        case "card":
            if arguments.dropFirst().first == "copy", let npub = try store.key()?.npub, await links.copy(npub) { toast = "Copied your key" }
        case "how":
            go(.how)
        case "about":
            go(.about)
        case "show", "again":
            go(.words)
        case "wrote":
            if try facts().sync == true {
                saved = nil
            } else {
                go(.check)
                places = Self.twoPlaces()
            }
        case "leave":
            go(.leave)
        case "back", "cancel", "done", "later":
            saved = nil
        case "sign_out":
            guard await links.allows("sign out of your account") else { throw SpotError.failed(1, "Touch ID didn't pass, so your account stays.") }
            try store.remove()
            saved = nil
            toast = "Signed out"
        case "sync":
            try store.setSyncing(arguments.dropFirst().first == "true")
        case let id where id.hasPrefix("pick-"):
            toast = try picked(id)
        default:
            throw SpotError.failed(1, "Account cannot do that.")
        }
        return try await sheet(reason: action == "read" ? reason : nil, toast: toast, phrase: phrase, pops: pops)
    }

    private func facts() throws -> Facts {
        let key = try store.key()
        return Facts(
            npub: key?.npub,
            name: key == nil ? nil : try store.name(),
            since: key == nil ? nil : try store.since(),
            isBackedUp: key == nil ? false : try store.isBackedUp(),
            sync: key == nil || !store.canSync ? nil : try store.isSyncing()
        )
    }

    private func step(reason: String?, _ facts: Facts) throws -> Step {
        if reason != nil, saved == .words { saved = nil }
        switch (saved, facts.isSignedIn) {
        case (.how?, _), (.restore?, _), (.name?, false): return saved ?? .choose
        case (.about?, true), (.words?, true), (.account?, true), (.leave?, true): return saved ?? .account
        case (.check?, true) where !facts.isBackedUp: return .check
        default: return facts.isSignedIn ? .account : .choose
        }
    }

    private func go(_ step: Step) {
        saved = step
        mistake = nil
        pick = nil
    }

    private func publish(_ id: String) async -> Bool {
        saved = nil
        await links.publish(id)
        return true
    }

    private func picked(_ id: String) throws -> String? {
        let rest = id.dropFirst("pick-".count)
        guard let dash = rest.firstIndex(of: "-"), let place = Int(rest[..<dash]) else { return nil }
        let word = String(rest[rest.index(after: dash)...])
        guard let first = pick, first.place != place else {
            pick = (place, word)
            return nil
        }
        guard let words = try store.key()?.words else { throw SpotError.failed(1, "This Mac holds no account words.") }
        for (at, chosen) in [first, (place, word)] where words.indices.contains(at - 1) && words[at - 1] != chosen.lowercased() {
            pick = nil
            mistake = "That isn't word \(at). Look at your words again."
            return nil
        }
        try store.markBackedUp()
        go(.account)
        return "Your words are backed up"
    }

    private static func twoPlaces() -> (Int, Int) {
        let first = Int.random(in: 1...12)
        var second = Int.random(in: 1...12)
        while second == first { second = Int.random(in: 1...12) }
        return (min(first, second), max(first, second))
    }

    private func sheet(reason: String?, toast: String?, phrase: String, pops: Bool) async throws -> String {
        let facts = try facts()
        var frame = AccountFrame()
        if pops { frame.head("pop", "true") }
        switch try step(reason: reason, facts) {
        case .restore: restore(&frame, facts, phrase: phrase, toast: toast)
        case .check: try check(&frame, toast: toast)
        case .choose: choose(&frame, toast: toast)
        case .name: name(&frame, toast: toast)
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

    private func name(_ frame: inout AccountFrame, toast: String?) {
        frame.grid("head head", "head head", "name name", "back create")
        frame.toast(toast)
        frame.line("head", "Who publishes?", icon: "person.crop.circle", detail: "People see this name on the spots you publish.")
        frame.block(["field": "name", "placeholder": "Your name", "value": links.userName()], order: ["field", "placeholder", "value"])
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

    private func about(_ frame: inout AccountFrame, _ facts: Facts, toast: String?) {
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

    private func words(_ frame: inout AccountFrame, _ facts: Facts, toast: String?) async {
        frame.grid("head head")
        frame.wordGrid()
        frame.grid("wrote wrote", "later later")
        frame.toast(toast)
        let words = try? store.key()?.words
        if words == nil {
            frame.line("head", "This Mac holds no account words.", icon: "exclamationmark.triangle", tone: "bad")
        } else if let words, await links.allows("show your account words") {
            frame.line("head", "Write them down", icon: "pencil", detail: "In this order")
            for (index, word) in words.enumerated() { frame.word(index + 1, word) }
        } else {
            frame.line("head", "Touch ID didn't pass, so Openspot showed no words.", icon: "exclamationmark.triangle", tone: "bad")
        }
        frame.button("wrote", "I wrote them down", .main)
        frame.button("later", facts.isBackedUp ? "Done" : "Later", .close)
        frame.howAction()
    }

    private func account(_ frame: inout AccountFrame, _ facts: Facts, toast: String?) {
        frame.grid("card card", "card card", "card card", "card card")
        if facts.sync != true { frame.grid("backup backup") }
        if facts.sync != nil { frame.grid("sync sync") }
        frame.grid("done done", "about how", "leave leave")
        frame.toast(toast)
        let npub = facts.npub ?? ""
        var card = ["view": "card", "npub": npub, "short": "\(npub.prefix(9))…\(npub.suffix(4))"]
        var order = ["view", "npub", "short"]
        if let name = facts.name { card["name"] = name; order.append("name") }
        if let since = facts.since.flatMap(Self.month) { card["since"] = since; order.append("since") }
        frame.block(card, order: order)
        if facts.sync == true {
        } else if facts.isBackedUp {
            frame.line("backup", "Your 12 words are backed up", icon: "checkmark.shield", tone: "good")
        } else {
            frame.line("backup", "Your 12 words are not backed up", icon: "exclamationmark.triangle", tone: "warn")
        }
        if let sync = facts.sync {
            frame.block(["switch": "sync", "title": "Keep in iCloud Keychain", "icon": "icloud", "look": "tile", "value": String(sync)], order: ["switch", "title", "icon", "look", "value"])
        }
        frame.button("done", "Done", .mainClosing)
        frame.button("about", "Show my words")
        frame.button("leave", "Sign out…")
        frame.howAction()
    }

    private func leave(_ frame: inout AccountFrame, _ facts: Facts, toast: String?) {
        frame.grid("head", "head")
        if !facts.isBackedUp { frame.grid("again") }
        frame.grid("sign_out", "cancel")
        frame.toast(toast)
        let place = facts.sync == true ? "all your Macs" : "this Mac"
        let again = facts.isBackedUp ? " Your 12 words sign you in again." : ""
        frame.line("head", "Sign out of your account?", icon: "rectangle.portrait.and.arrow.right", detail: "It leaves \(place).\(again)")
        if !facts.isBackedUp { frame.line("again", "You haven't saved its words", icon: "exclamationmark.triangle", tone: "bad") }
        frame.button("sign_out", "Sign out", .main)
        frame.button("cancel", "Cancel")
        frame.howAction()
    }

    private func restore(_ frame: inout AccountFrame, _ facts: Facts, phrase: String, toast: String?) {
        let typed = phrase.isEmpty ? nil : AccountPhrase(phrase)
        let words = typed?.typed ?? []
        var status: (title: String, icon: String, tone: String?, detail: String?)?
        if let problem = typed?.problem {
            status = (problem, "exclamationmark.triangle", "bad", nil)
        } else if let account = typed?.account {
            status = facts.isSignedIn
                ? ("Replaces the account on this Mac", "exclamationmark.triangle", "warn", Self.short(account))
                : ("Signs in as", "checkmark.circle", "good", Self.short(account))
        } else if let completion = typed?.completion {
            status = ("Did you mean \(completion)?", "questionmark.circle", nil, nil)
        }
        frame.grid("phrase phrase")
        frame.wordGrid()
        if status != nil { frame.grid("status status") }
        frame.grid("back sign_in")
        frame.toast(toast)
        frame.block(["field": "phrase", "type": "multiline", "placeholder": "Your 12 words, or an nsec", "value": phrase], order: ["field", "type", "placeholder", "value"])
        for place in 1...AccountPhrase.wordCount {
            if place <= words.count {
                frame.word(place, words[place - 1].text, tone: words[place - 1].isKnown ? nil : "bad")
            } else {
                frame.word(place, " ")
            }
        }
        if let status { frame.line("status", status.title, icon: status.icon, tone: status.tone, detail: status.detail) }
        frame.button("sign_in", "Sign in", .main)
        frame.button("back", "Back")
    }

    private func check(_ frame: inout AccountFrame, toast: String?) throws {
        let key = try store.key()
        let (first, second) = places
        let choices = [first, second].map { key?.words == nil ? [] : (key?.choices(at: $0) ?? []) }
        let ids = zip([first, second], choices).map { place, words in words.map { "pick-\(place)-\($0)" } }
        frame.grid("head head", "first first")
        if ids[0].count == 4 { frame.grid("\(ids[0][0]) \(ids[0][1])", "\(ids[0][2]) \(ids[0][3])") }
        frame.grid("second second")
        if ids[1].count == 4 { frame.grid("\(ids[1][0]) \(ids[1][1])", "\(ids[1][2]) \(ids[1][3])") }
        frame.grid("again again")
        frame.toast(toast)
        if let mistake {
            frame.line("head", mistake, icon: "exclamationmark.triangle", tone: "bad")
        } else {
            frame.line("head", "Pick each word you wrote", icon: "checkmark.circle")
        }
        frame.block(["text": "first", "title": "Word \(first)", "icon": "\(first).circle"], order: ["text", "title", "icon"])
        frame.block(["text": "second", "title": "Word \(second)", "icon": "\(second).circle"], order: ["text", "title", "icon"])
        for (place, words) in zip([first, second], choices) {
            for word in words {
                let isPicked = pick.map { $0.place == place && $0.word == word } ?? false
                frame.button("pick-\(place)-\(word)", word, isPicked ? .picked : .plain)
            }
        }
        frame.button("again", "Show the words again")
    }

    private static func short(_ npub: String) -> String {
        "\(npub.prefix(12))…\(npub.suffix(6))"
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
